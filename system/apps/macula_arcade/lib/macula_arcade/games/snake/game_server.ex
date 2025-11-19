defmodule MaculaArcade.Games.Snake.GameServer do
  @moduledoc """
  Snake Battle Royale game server.

  Manages game state for a 2-player competitive snake game:
  - 60 FPS game loop
  - Collision detection
  - Score tracking
  - State synchronization via Macula pub/sub
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh.NodeManager
  alias MaculaArcade.Games.Coordinator

  # Grid is 40x30 cells
  @grid_width 40
  @grid_height 30
  @tick_interval 50  # ~20 FPS (balanced for smooth gameplay over mesh)
  @initial_snake_length 3
  @bot_enabled true  # AI controls both snakes - spectator mode

  defmodule State do
    defstruct [
      :game_id,
      :player1_id,
      :player2_id,
      :player1_snake,
      :player2_snake,
      :player1_direction,
      :player2_direction,
      :player1_score,
      :player2_score,
      :food_position,
      :game_status,  # :waiting | :running | :finished
      :winner,
      :timer_ref,
      :player1_asshole_factor,  # 0-100: willingness to play dirty
      :player2_asshole_factor,
      player1_events: [],  # Event feed for player 1
      player2_events: []   # Event feed for player 2
    ]
  end

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Starts a new game with two players.
  """
  def start_game(server, player1_id, player2_id) do
    GenServer.call(server, {:start_game, player1_id, player2_id})
  end

  @doc """
  Updates a player's direction.
  """
  def update_direction(server, player_id, direction) do
    GenServer.cast(server, {:update_direction, player_id, direction})
  end

  @doc """
  Submit a player action (direction change).
  Returns {:ok, tick} on success.
  """
  def submit_action(server, player_id, action) when is_binary(action) do
    direction = String.to_existing_atom(action)
    GenServer.call(server, {:submit_action, player_id, direction})
  rescue
    ArgumentError -> {:error, :invalid_action}
  end

  def submit_action(server, player_id, action) when is_atom(action) do
    GenServer.call(server, {:submit_action, player_id, action})
  end

  @doc """
  Gets the current game state.
  """
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.get(opts, :game_id, generate_game_id())
    Logger.info("Snake GameServer starting for game #{game_id}")

    state = %State{
      game_id: game_id,
      game_status: :waiting
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_game, player1_id, player2_id}, _from, state) do
    # Use current time for truly random behavior each game
    # This creates more variety in food positions and AI decisions
    :rand.seed(:exsss, {:erlang.monotonic_time(), :erlang.unique_integer(), :erlang.phash2(state.game_id)})

    # Initialize game state with random personality traits
    # Asshole factor: 0 = fair play gentleman, 100 = total jerk who cuts you off
    new_state = %{state |
      player1_id: player1_id,
      player2_id: player2_id,
      player1_snake: initial_snake_position(:player1),
      player2_snake: initial_snake_position(:player2),
      player1_direction: :right,
      player2_direction: :left,
      player1_score: 0,
      player2_score: 0,
      food_position: spawn_food([]),
      game_status: :running,
      player1_asshole_factor: :rand.uniform(100),
      player2_asshole_factor: :rand.uniform(100)
    }

    # Start game loop
    timer_ref = schedule_tick()
    new_state = %{new_state | timer_ref: timer_ref}

    # Broadcast initial state
    broadcast_state(new_state)

    Logger.info("Game #{new_state.game_id} started with #{player1_id} vs #{player2_id}")
    {:reply, {:ok, new_state.game_id}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, serialize_state(state), state}
  end

  @impl true
  def handle_call({:submit_action, player_id, direction}, _from, state)
      when direction in [:up, :down, :left, :right] do
    cond do
      state.game_status != :running ->
        {:reply, {:error, :game_not_running}, state}

      player_id == state.player1_id and not opposite?(direction, state.player1_direction) ->
        {:reply, {:ok, 0}, %{state | player1_direction: direction}}

      player_id == state.player2_id and not opposite?(direction, state.player2_direction) ->
        {:reply, {:ok, 0}, %{state | player2_direction: direction}}

      player_id == state.player1_id or player_id == state.player2_id ->
        # Invalid direction change (would reverse)
        {:reply, {:error, :invalid_direction}, state}

      true ->
        {:reply, {:error, :not_in_game}, state}
    end
  end

  def handle_call({:submit_action, _player_id, _direction}, _from, state) do
    {:reply, {:error, :invalid_action}, state}
  end

  @impl true
  def handle_cast({:update_direction, player_id, direction}, state)
      when direction in [:up, :down, :left, :right] do
    new_state = cond do
      player_id == state.player1_id and not opposite?(direction, state.player1_direction) ->
        %{state | player1_direction: direction}

      player_id == state.player2_id and not opposite?(direction, state.player2_direction) ->
        %{state | player2_direction: direction}

      true ->
        state
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, %{game_status: :running} = state) do
    Logger.debug("Tick for game #{state.game_id}")

    # Store old directions for event tracking
    old_p1_dir = state.player1_direction
    old_p2_dir = state.player2_direction

    # Apply bot AI if enabled
    state = if @bot_enabled do
      %{state |
        player1_direction: bot_choose_direction(state.player1_snake, state.player1_direction, state.food_position, state.player2_snake, state.player1_asshole_factor),
        player2_direction: bot_choose_direction(state.player2_snake, state.player2_direction, state.food_position, state.player1_snake, state.player2_asshole_factor)
      }
    else
      state
    end

    # Track direction changes
    state = track_direction_change(state, :player1, old_p1_dir, state.player1_direction)
    state = track_direction_change(state, :player2, old_p2_dir, state.player2_direction)

    # Move snakes
    new_player1_snake = move_snake(state.player1_snake, state.player1_direction)
    new_player2_snake = move_snake(state.player2_snake, state.player2_direction)

    # Check collisions
    {game_over, winner} = check_collisions(
      new_player1_snake,
      new_player2_snake,
      state.player1_id,
      state.player2_id
    )

    new_state = if game_over do
      # Determine winner by score (highest score wins)
      # If collision caused game over, use scores to determine actual winner
      final_winner = determine_winner_by_score(
        state.player1_id, state.player1_score,
        state.player2_id, state.player2_score,
        winner
      )

      Logger.info("Game #{state.game_id} finished, winner: #{inspect(final_winner)} (P1: #{state.player1_score}, P2: #{state.player2_score})")

      # Notify Coordinator to remove players from in_game set
      Coordinator.game_ended(state.game_id, state.player1_id, state.player2_id, final_winner)

      # Track collision events
      collision_state = track_collision_events(state, new_player1_snake, new_player2_snake, winner)

      %{collision_state |
        game_status: :finished,
        winner: final_winner,
        player1_snake: new_player1_snake,
        player2_snake: new_player2_snake
      }
    else
      # First update snakes with movement, then check food consumption
      # (food consumption will grow the snake if it ate food)
      state
      |> Map.put(:player1_snake, new_player1_snake)
      |> Map.put(:player2_snake, new_player2_snake)
      |> check_food_consumption(:player1)
      |> check_food_consumption(:player2)
    end

    # Broadcast state
    broadcast_state(new_state)

    # Schedule next tick
    timer_ref = schedule_tick()
    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_info(:tick, state) do
    # Game not running, just reschedule
    timer_ref = schedule_tick()
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  ## Private Functions

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp initial_snake_position(:player1) do
    # Start on top-left area, heading right
    [
      {5, 5},
      {4, 5},
      {3, 5}
    ]
  end

  defp initial_snake_position(:player2) do
    # Start on bottom-right area, heading left
    [
      {@grid_width - 6, @grid_height - 6},
      {@grid_width - 5, @grid_height - 6},
      {@grid_width - 4, @grid_height - 6}
    ]
  end

  defp spawn_food(snakes) do
    # Generate random position avoiding snakes and walls
    all_snake_cells = Enum.flat_map(snakes, & &1)

    # Add extra randomization with different spawn zones
    zone = :rand.uniform(5)

    Stream.repeatedly(fn ->
      # Different spawn strategies based on zone
      {x, y} = case zone do
        1 ->
          # Top-left quadrant
          {:rand.uniform(div(@grid_width, 2)) - 1,
           :rand.uniform(div(@grid_height, 2)) - 1}
        2 ->
          # Top-right quadrant
          {div(@grid_width, 2) + :rand.uniform(div(@grid_width, 2)) - 1,
           :rand.uniform(div(@grid_height, 2)) - 1}
        3 ->
          # Bottom-left quadrant
          {:rand.uniform(div(@grid_width, 2)) - 1,
           div(@grid_height, 2) + :rand.uniform(div(@grid_height, 2)) - 1}
        4 ->
          # Bottom-right quadrant
          {div(@grid_width, 2) + :rand.uniform(div(@grid_width, 2)) - 1,
           div(@grid_height, 2) + :rand.uniform(div(@grid_height, 2)) - 1}
        5 ->
          # Center zone (more contested)
          {div(@grid_width, 4) + :rand.uniform(div(@grid_width, 2)) - 1,
           div(@grid_height, 4) + :rand.uniform(div(@grid_height, 2)) - 1}
      end

      # Ensure within bounds
      {min(max(x, 1), @grid_width - 2), min(max(y, 1), @grid_height - 2)}
    end)
    |> Enum.find(fn pos -> pos not in all_snake_cells end)
  end

  defp move_snake(snake, direction) do
    [head | _tail] = snake
    new_head = move_position(head, direction)
    # Keep all segments except the last one, then prepend the new head
    [new_head | Enum.slice(snake, 0..-2//1)]
  end

  defp move_position({x, y}, :up), do: {x, y - 1}
  defp move_position({x, y}, :down), do: {x, y + 1}
  defp move_position({x, y}, :left), do: {x - 1, y}
  defp move_position({x, y}, :right), do: {x + 1, y}

  defp opposite?(:up, :down), do: true
  defp opposite?(:down, :up), do: true
  defp opposite?(:left, :right), do: true
  defp opposite?(:right, :left), do: true
  defp opposite?(_, _), do: false

  defp check_collisions(snake1, snake2, player1_id, player2_id) do
    [head1 | _] = snake1
    [head2 | _] = snake2

    # Wall collision
    wall_collision1 = wall_collision?(head1)
    wall_collision2 = wall_collision?(head2)

    # Self collision
    self_collision1 = self_collision?(snake1)
    self_collision2 = self_collision?(snake2)

    # Other snake collision
    other_collision1 = head_collision?(head1, snake2)
    other_collision2 = head_collision?(head2, snake1)

    # Head-to-head collision
    head_collision = head1 == head2

    cond do
      head_collision ->
        {true, :draw}

      wall_collision1 or self_collision1 or other_collision1 ->
        {true, player2_id}

      wall_collision2 or self_collision2 or other_collision2 ->
        {true, player1_id}

      true ->
        {false, nil}
    end
  end

  defp wall_collision?({x, y}) do
    x < 0 or x >= @grid_width or y < 0 or y >= @grid_height
  end

  defp self_collision?([head | tail]) do
    head in tail
  end

  defp head_collision?(head, snake) do
    head in snake
  end

  # Determine winner - collision winner takes priority, then score for head-to-head
  defp determine_winner_by_score(player1_id, score1, player2_id, score2, collision_winner) do
    case collision_winner do
      # Only use score for head-to-head collisions (draw from check_collisions)
      :draw ->
        cond do
          score1 > score2 -> player1_id
          score2 > score1 -> player2_id
          true -> :draw  # Equal scores = draw
        end
      # Otherwise, collision winner is the actual winner
      winner -> winner
    end
  end

  defp check_food_consumption(state, :player1) do
    snake = state.player1_snake
    [head | _] = snake

    if head == state.food_position do
      # Grow snake
      grown_snake = grow_snake(snake)

      # Update score
      new_score = state.player1_score + 1

      # Spawn new food
      new_food = spawn_food([grown_snake, state.player2_snake])

      # Add food event
      %{state |
        player1_snake: grown_snake,
        player1_score: new_score,
        food_position: new_food,
        player1_events: add_event(state.player1_events, {:food, new_score})
      }
    else
      state
    end
  end

  defp check_food_consumption(state, :player2) do
    snake = state.player2_snake
    [head | _] = snake

    if head == state.food_position do
      # Grow snake
      grown_snake = grow_snake(snake)

      # Update score
      new_score = state.player2_score + 1

      # Spawn new food
      new_food = spawn_food([state.player1_snake, grown_snake])

      # Add food event
      %{state |
        player2_snake: grown_snake,
        player2_score: new_score,
        food_position: new_food,
        player2_events: add_event(state.player2_events, {:food, new_score})
      }
    else
      state
    end
  end

  defp grow_snake(snake) do
    # Add a segment to the tail
    [last | _] = Enum.reverse(snake)
    snake ++ [last]
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp serialize_state(state) do
    %{
      game_id: state.game_id,
      player1_id: state.player1_id,
      player2_id: state.player2_id,
      player1_snake: tuples_to_lists(state.player1_snake),
      player2_snake: tuples_to_lists(state.player2_snake),
      player1_score: state.player1_score,
      player2_score: state.player2_score,
      food_position: tuple_to_list_or_nil(state.food_position),
      game_status: state.game_status,
      winner: state.winner,
      player1_events: serialize_events(state.player1_events),
      player2_events: serialize_events(state.player2_events),
      player1_asshole_factor: state.player1_asshole_factor,
      player2_asshole_factor: state.player2_asshole_factor
    }
  end

  # Convert list of tuples to list of lists for JSON serialization
  defp tuples_to_lists(nil), do: nil
  defp tuples_to_lists(positions) when is_list(positions) do
    Enum.map(positions, fn {x, y} -> [x, y] end)
  end

  # Convert single tuple to list for JSON serialization
  defp tuple_to_list_or_nil(nil), do: nil
  defp tuple_to_list_or_nil({x, y}), do: [x, y]

  ## Event tracking helpers

  # Add event to list, keep only last 30 events
  defp add_event(events, event) when is_list(events) do
    [event | events] |> Enum.take(30)
  end
  defp add_event(nil, event), do: [event]

  # Track direction change as event
  defp track_direction_change(state, :player1, old_dir, new_dir) when old_dir != new_dir do
    %{state | player1_events: add_event(state.player1_events, {:turn, new_dir})}
  end
  defp track_direction_change(state, :player2, old_dir, new_dir) when old_dir != new_dir do
    %{state | player2_events: add_event(state.player2_events, {:turn, new_dir})}
  end
  defp track_direction_change(state, _, _, _), do: state

  # Track collision events
  defp track_collision_events(state, new_player1_snake, new_player2_snake, winner) do
    [head1 | _] = new_player1_snake
    [head2 | _] = new_player2_snake

    # Check what kind of collision each player had
    p1_wall = wall_collision?(head1)
    p1_self = self_collision?(new_player1_snake)
    p1_other = head_collision?(head1, new_player2_snake)

    p2_wall = wall_collision?(head2)
    p2_self = self_collision?(new_player2_snake)
    p2_other = head_collision?(head2, new_player1_snake)

    head_to_head = head1 == head2

    state
    |> add_collision_event(:player1, p1_wall, p1_self, p1_other, head_to_head, winner)
    |> add_collision_event(:player2, p2_wall, p2_self, p2_other, head_to_head, winner)
  end

  defp add_collision_event(state, :player1, wall, self, other, head_to_head, winner) do
    event = cond do
      head_to_head -> {:collision, :head_to_head}
      wall -> {:collision, :wall}
      self -> {:collision, :self}
      other -> {:collision, :snake}
      winner == state.player1_id -> {:win, :opponent_crash}
      true -> {:collision, :unknown}
    end
    %{state | player1_events: add_event(state.player1_events, event)}
  end

  defp add_collision_event(state, :player2, wall, self, other, head_to_head, winner) do
    event = cond do
      head_to_head -> {:collision, :head_to_head}
      wall -> {:collision, :wall}
      self -> {:collision, :self}
      other -> {:collision, :snake}
      winner == state.player2_id -> {:win, :opponent_crash}
      true -> {:collision, :unknown}
    end
    %{state | player2_events: add_event(state.player2_events, event)}
  end

  # Serialize events for JSON
  defp serialize_events(nil), do: []
  defp serialize_events(events) when is_list(events) do
    Enum.map(events, fn
      {:food, score} -> %{type: "food", value: score}
      {:turn, direction} -> %{type: "turn", value: Atom.to_string(direction)}
      {:collision, kind} -> %{type: "collision", value: Atom.to_string(kind)}
      {:win, reason} -> %{type: "win", value: Atom.to_string(reason)}
      _ -> %{type: "unknown", value: nil}
    end)
  end

  defp broadcast_state(state) do
    game_topic = "arcade.game.#{state.game_id}.state"
    state_data = serialize_state(state)

    # Broadcast via mesh (for multi-container)
    # Use try/catch to prevent NodeManager crashes from affecting game
    try do
      NodeManager.publish(game_topic, state_data)
    catch
      :exit, reason ->
        Logger.warning("Failed to publish game state via mesh: #{inspect(reason)}")
    end

    # Also broadcast locally via Phoenix PubSub (for single-container)
    Phoenix.PubSub.broadcast(MaculaArcade.PubSub, game_topic, {:game_state_update, state_data})
  end

  ## Bot AI Functions

  # AI that tries to move towards food while avoiding walls and itself
  # Asshole factor (0-100) determines how aggressively it plays dirty
  defp bot_choose_direction(snake, current_direction, food_position, other_snake, asshole_factor) do
    [head | _] = snake

    # Calculate possible directions (excluding reverse of current)
    possible = [:up, :down, :left, :right]
    |> Enum.reject(&opposite?(&1, current_direction))

    # Predict opponent's possible next positions (for head-to-head avoidance)
    [other_head | _] = other_snake
    opponent_next_positions = predict_opponent_positions(other_head)

    # Score each direction
    scored = Enum.map(possible, fn dir ->
      new_pos = move_position(head, dir)
      score = direction_score(new_pos, food_position, snake, other_snake, opponent_next_positions, asshole_factor)
      {dir, score}
    end)

    # Choose the direction with best score
    {best_dir, _score} = Enum.max_by(scored, fn {_dir, score} -> score end)
    best_dir
  end

  # Predict all possible positions the opponent's head could move to
  defp predict_opponent_positions({x, y}) do
    [
      {x, y - 1},  # up
      {x, y + 1},  # down
      {x - 1, y},  # left
      {x + 1, y}   # right
    ]
  end

  defp direction_score(pos, food_position, own_snake, other_snake, opponent_next_positions, asshole_factor) do
    {x, y} = pos
    {food_x, food_y} = food_position

    # Immediate death checks - these are absolute disqualifiers
    cond do
      wall_collision?(pos) -> -1000
      pos in own_snake -> -1000
      pos in other_snake -> -1000
      true ->
        # Calculate reachable space using flood fill (most important for survival)
        all_obstacles = MapSet.new(own_snake ++ other_snake)
        reachable_space = flood_fill_count(pos, all_obstacles, 50)

        # Base score from reachable space (survival is priority #1)
        score = reachable_space * 2

        # Head-to-head collision handling - assholes are more willing to risk it
        # High asshole factor = less penalty for contested spaces (risky but aggressive)
        # Low asshole factor = cautious, avoids head-to-head at all costs
        head_collision_penalty = 50 - div(asshole_factor, 2)  # 50 (nice) to 0 (asshole)
        score = if pos in opponent_next_positions, do: score - head_collision_penalty, else: score

        # Stronger bonus for getting closer to food (encourages aggression)
        old_dist = abs(elem(hd(own_snake), 0) - food_x) + abs(elem(hd(own_snake), 1) - food_y)
        new_dist = abs(x - food_x) + abs(y - food_y)
        score = score + (old_dist - new_dist) * 15

        # Penalty for being near walls (reduces maneuverability)
        score = if x < 2 or x > @grid_width - 3 or y < 2 or y > @grid_height - 3, do: score - 5, else: score

        # Count immediate escape routes
        escape_routes = count_escape_routes(pos, own_snake, other_snake)
        score = score + escape_routes * 5

        # Heavy penalty for very small reachable areas (trap detection)
        snake_length = length(own_snake)
        score = if reachable_space < snake_length + 3, do: score - 100, else: score

        # ASSHOLE BEHAVIOR: Cut off opponent's space
        # Higher asshole factor = more willing to sacrifice own space to trap opponent
        [other_head | _] = other_snake
        opponent_reachable = flood_fill_count(other_head, MapSet.new(own_snake ++ [pos] ++ other_snake), 30)
        # Assholes get bonus for reducing opponent space
        cutoff_bonus = div((30 - opponent_reachable) * asshole_factor, 100)
        score = score + cutoff_bonus

        # ASSHOLE BEHAVIOR: Steal food from opponent
        # If opponent is closer to food, an asshole will prioritize blocking them
        opponent_food_dist = abs(elem(other_head, 0) - food_x) + abs(elem(other_head, 1) - food_y)
        our_food_dist = abs(x - food_x) + abs(y - food_y)
        # If opponent is closer but we can get there, bonus for aggressive food pursuit
        steal_bonus = if opponent_food_dist < our_food_dist and our_food_dist < 5 do
          div(asshole_factor, 5)  # 0 to 20 bonus
        else
          0
        end
        score = score + steal_bonus

        # ASSHOLE BEHAVIOR: Body blocking
        # Assholes prefer positions that limit opponent's options
        opponent_escape_routes = count_escape_routes(other_head, own_snake ++ [pos], other_snake)
        # Fewer escape routes for opponent = bonus for asshole
        blocking_bonus = div((4 - opponent_escape_routes) * asshole_factor, 50)
        score = score + blocking_bonus

        # Add randomness to make games unpredictable
        # Higher asshole factor = more erratic/unpredictable behavior
        random_range = 50 + div(asshole_factor, 4)  # 50 to 75
        random_factor = :rand.uniform(random_range) - div(random_range, 2)

        # Occasionally make "risky" moves - assholes do this more often
        aggression_chance = 5 + div(asshole_factor, 10)  # 5% to 15%
        aggression_bonus = if :rand.uniform(100) <= aggression_chance, do: :rand.uniform(30), else: 0

        score + random_factor + aggression_bonus
    end
  end

  # Flood fill to count reachable space from a position
  # Returns count of cells reachable without hitting obstacles or walls
  defp flood_fill_count(start_pos, obstacles, max_count) do
    do_flood_fill([start_pos], MapSet.new([start_pos]), obstacles, 0, max_count)
  end

  defp do_flood_fill([], _visited, _obstacles, count, _max_count), do: count
  defp do_flood_fill(_queue, _visited, _obstacles, count, max_count) when count >= max_count, do: count
  defp do_flood_fill([{x, y} | rest], visited, obstacles, count, max_count) do
    neighbors = [
      {x, y - 1},
      {x, y + 1},
      {x - 1, y},
      {x + 1, y}
    ]

    # Find unvisited, valid neighbors
    new_cells = Enum.filter(neighbors, fn neighbor ->
      not MapSet.member?(visited, neighbor) and
      not wall_collision?(neighbor) and
      not MapSet.member?(obstacles, neighbor)
    end)

    new_visited = Enum.reduce(new_cells, visited, &MapSet.put(&2, &1))
    new_queue = rest ++ new_cells

    do_flood_fill(new_queue, new_visited, obstacles, count + 1, max_count)
  end

  # Count how many directions are safe from a given position
  defp count_escape_routes({x, y}, own_snake, other_snake) do
    neighbors = [
      {x, y - 1},  # up
      {x, y + 1},  # down
      {x - 1, y},  # left
      {x + 1, y}   # right
    ]

    Enum.count(neighbors, fn neighbor_pos ->
      not wall_collision?(neighbor_pos) and
      neighbor_pos not in own_snake and
      neighbor_pos not in other_snake
    end)
  end
end
