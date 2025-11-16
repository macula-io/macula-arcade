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

  # Grid is 40x30 cells
  @grid_width 40
  @grid_height 30
  @tick_interval 16  # ~60 FPS (1000ms / 60)
  @initial_snake_length 3

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
      :timer_ref
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
    # Initialize game state
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
      game_status: :running
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
      Logger.info("Game #{state.game_id} finished, winner: #{inspect(winner)}")
      %{state |
        game_status: :finished,
        winner: winner,
        player1_snake: new_player1_snake,
        player2_snake: new_player2_snake
      }
    else
      # Check food consumption
      state
      |> check_food_consumption(new_player1_snake, :player1)
      |> check_food_consumption(new_player2_snake, :player2)
      |> Map.put(:player1_snake, new_player1_snake)
      |> Map.put(:player2_snake, new_player2_snake)
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
    # Start on left side
    [
      {5, div(@grid_height, 2)},
      {4, div(@grid_height, 2)},
      {3, div(@grid_height, 2)}
    ]
  end

  defp initial_snake_position(:player2) do
    # Start on right side
    [
      {@grid_width - 6, div(@grid_height, 2)},
      {@grid_width - 5, div(@grid_height, 2)},
      {@grid_width - 4, div(@grid_height, 2)}
    ]
  end

  defp spawn_food(snakes) do
    # Generate random position avoiding snakes
    all_snake_cells = Enum.flat_map(snakes, & &1)

    Stream.repeatedly(fn ->
      {
        :rand.uniform(@grid_width) - 1,
        :rand.uniform(@grid_height) - 1
      }
    end)
    |> Enum.find(fn pos -> pos not in all_snake_cells end)
  end

  defp move_snake([head | tail], direction) do
    new_head = move_position(head, direction)
    [new_head | Enum.slice(tail, 0..-2//1)]
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

  defp check_food_consumption(state, snake, player) do
    [head | _] = snake

    if head == state.food_position do
      # Grow snake
      grown_snake = grow_snake(snake)

      # Update score
      new_score = if player == :player1, do: state.player1_score + 1, else: state.player2_score + 1

      # Spawn new food
      new_food = spawn_food([state.player1_snake, state.player2_snake])

      state
      |> Map.put(:"#{player}_snake", grown_snake)
      |> Map.put(:"#{player}_score", new_score)
      |> Map.put(:food_position, new_food)
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
      player1_snake: state.player1_snake,
      player2_snake: state.player2_snake,
      player1_score: state.player1_score,
      player2_score: state.player2_score,
      food_position: state.food_position,
      game_status: state.game_status,
      winner: state.winner
    }
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
end
