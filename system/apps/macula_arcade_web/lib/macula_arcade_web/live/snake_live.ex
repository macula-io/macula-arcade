defmodule MaculaArcadeWeb.SnakeLive do
  @moduledoc """
  LiveView for Snake Duel game (1v1).

  Handles:
  - Player registration and matchmaking
  - Game state display (AI-controlled snakes)
  - Real-time updates from Macula mesh
  """

  use MaculaArcadeWeb, :live_view
  require Logger
  alias MaculaArcade.Games.Coordinator
  alias MaculaArcade.Mesh

  @impl true
  def mount(_params, _session, socket) do
    player_id = generate_player_id()
    # Capture LiveView pid for use in mesh callbacks
    live_view_pid = self()

    # Subscribe to game start events early (before user clicks Find Game)
    # This ensures we don't miss the event due to race conditions

    # Subscribe via Phoenix PubSub (for single-container)
    Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.start")

    # Subscribe via Macula mesh (for multi-container)
    client = Mesh.client()
    case :macula.subscribe(client, "arcade.game.start", fn event_data ->
           # Convert mesh event to LiveView message
           send(live_view_pid, {:game_started, event_data})
           :ok
         end) do
      {:ok, _sub_ref} ->
        Logger.info("SnakeLive subscribed to game start events via mesh")
      {:error, reason} ->
        Logger.warn("Cannot subscribe to game start via mesh - #{inspect(reason)}")
    end

    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:game_id, nil)
      |> assign(:game_state, nil)
      |> assign(:status, :lobby)
      |> assign(:waiting, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_queue", _params, socket) do
    Logger.info("Player #{socket.assigns.player_id} joining queue")

    # Reset state if coming from a finished game (Play Again)
    socket = if socket.assigns.status == :playing do
      socket
      |> assign(:game_id, nil)
      |> assign(:game_state, nil)
      |> assign(:status, :lobby)
    else
      socket
    end

    # Register for matchmaking (v0.2.0 protocol)
    case Coordinator.register_player(socket.assigns.player_id) do
      {:ok, %{queue_position: pos}} ->
        Logger.info("Player registered at position #{pos}")

        socket =
          socket
          |> assign(:waiting, true)
          |> assign(:status, :waiting)
          |> assign(:queue_position, pos)

        {:noreply, socket}

      {:error, reason} ->
        Logger.warning("Failed to register: #{inspect(reason)}")
        {:noreply, assign(socket, :error, "Failed to join: #{reason}")}
    end
  end

  @impl true
  def handle_event("key_press", %{"key" => key}, socket) do
    direction = key_to_direction(key)

    with {:ok, game_id} when not is_nil(game_id) <- {:ok, socket.assigns.game_id},
         {:ok, direction} when not is_nil(direction) <- {:ok, direction} do
      # Publish direction change to mesh
      topic = "arcade.game.#{game_id}.input"
      client = Mesh.client()
      :macula.publish(client, topic, %{
        player_id: socket.assigns.player_id,
        direction: direction
      })
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_started, %{game_id: game_id, player1_id: p1, player2_id: p2}}, socket) do
    player_id = socket.assigns.player_id
    Logger.info("SnakeLive received game_started: game=#{game_id}, p1=#{p1}, p2=#{p2}, our_player=#{player_id}")

    # Check if this player is in the game
    if player_id in [p1, p2] do
      Logger.info("Player #{player_id} matched in game #{game_id} - transitioning to :playing")
      # Capture LiveView pid for use in mesh callbacks
      live_view_pid = self()

      # Subscribe to game state updates via mesh (for multi-container)
      client = Mesh.client()
      case :macula.subscribe(client, "arcade.game.#{game_id}.state", fn state_data ->
             send(live_view_pid, {:game_state_update, state_data})
             :ok
           end) do
        {:ok, _sub_ref} -> :ok
        {:error, :not_connected} -> Logger.warn("Cannot subscribe to game state via mesh - not connected")
      end

      # Also subscribe via Phoenix PubSub (for single-container)
      Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.#{game_id}.state")

      # Subscribe to player input via mesh (for multi-container)
      client = Mesh.client()
      case :macula.subscribe(client, "arcade.game.#{game_id}.input", fn input_data ->
             send(live_view_pid, {:player_input, input_data})
             :ok
           end) do
        {:ok, _sub_ref} -> :ok
        {:error, :not_connected} -> Logger.warn("Cannot subscribe to player input via mesh - not connected")
      end

      socket =
        socket
        |> assign(:game_id, game_id)
        |> assign(:status, :playing)
        |> assign(:waiting, false)
        |> assign(:game_state, %{
          game_id: game_id,
          player1_id: p1,
          player2_id: p2,
          player1_snake: [],
          player2_snake: [],
          player1_score: 0,
          player2_score: 0,
          food_position: {0, 0},
          game_status: :running,
          winner: nil,
          player1_events: [],
          player2_events: [],
          player1_asshole_factor: 0,
          player2_asshole_factor: 0
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_state_update, message}, socket) do
    # Extract payload from mesh message envelope (may have :topic and :payload keys)
    # or use the message directly if it's already the game state
    payload = case message do
      %{payload: p} -> p
      %{"payload" => p} -> p
      state -> state
    end

    # Normalize to atom keys for template access
    game_state = normalize_game_state(payload)

    # Log at info level every 60 updates (once per second at 60 FPS)
    if rem(:erlang.unique_integer([:positive]), 60) == 0 do
      Logger.info("SnakeLive received game_state_update for game #{inspect(game_state.game_id)}")
    end

    socket =
      socket
      |> assign(:game_state, game_state)
      |> push_event("game_state_update", %{game_state: serialize_game_state(game_state)})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_input, %{player_id: _player_id, direction: _direction}}, socket) do
    # Input handled by backend GameServer
    {:noreply, socket}
  end

  # Catch-all for game_started with unexpected format
  @impl true
  def handle_info({:game_started, data}, socket) do
    Logger.warning("SnakeLive received game_started with unexpected format: #{inspect(data)}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-4xl font-bold text-center mb-8">
          Snake Duel
        </h1>

        <%= if @status == :lobby do %>
          <div class="text-center">
            <p class="text-xl mb-4">Challenge another player to a 1v1 Snake Duel!</p>
            <p class="text-gray-400 mb-8">Player ID: <%= @player_id %></p>
            <button
              phx-click="join_queue"
              class="bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-6 rounded-lg text-xl"
            >
              Find Game
            </button>
          </div>
        <% end %>

        <%= if @status == :waiting do %>
          <div class="text-center">
            <p class="text-xl mb-4">Looking for opponent...</p>
            <div class="animate-pulse text-6xl">⏳</div>
          </div>
        <% end %>

        <%= if @status == :playing && @game_state do %>
          <div class="game-container">
            <%# Player identification banner %>
            <div class="text-center mb-4 text-lg">
              You are
              <%= if @player_id == @game_state.player1_id do %>
                <span class="text-blue-400 font-bold">Player 1 (Blue)</span>
              <% else %>
                <span class="text-red-400 font-bold">Player 2 (Red)</span>
              <% end %>
            </div>

            <%# 3-Column Layout: Player 1 | Arena | Player 2 %>
            <div class="flex justify-center gap-4 items-stretch">
              <%# Player 1 Panel (Left Column) - matches arena height %>
              <div class="w-48 flex flex-col" style="height: 608px;">
                <div class="text-center mb-2">
                  <div class="text-blue-400 font-semibold text-lg">
                    Player 1
                    <%= if @player_id == @game_state.player1_id do %>
                      <span class="text-xs text-gray-400">(You)</span>
                    <% end %>
                  </div>
                  <div class="text-4xl font-bold text-blue-300"><%= @game_state.player1_score %></div>
                </div>
                <%# Character Description %>
                <div class="text-xs text-center mb-1 px-2">
                  <span class="text-gray-400"><%= character_description(@game_state.player1_asshole_factor) %></span>
                </div>
                <%# Personality Indicator %>
                <div class="text-xs text-gray-500 text-center mb-2">
                  <%= asshole_indicator(@game_state.player1_asshole_factor) %>
                </div>
                <%# Event Feed - fills remaining height %>
                <div class="flex-1 bg-gray-800 rounded-lg p-3 flex flex-col overflow-hidden">
                  <div class="text-xs text-gray-500 mb-2 uppercase tracking-wide">Events</div>
                  <div class="flex-1 overflow-y-auto flex flex-col-reverse font-mono text-sm">
                    <%= for event <- @game_state.player1_events do %>
                      <div class="text-blue-300 truncate py-0.5"><%= format_event(event) %></div>
                    <% end %>
                  </div>
                </div>
              </div>

              <%# Arena (Center Column) %>
              <div class="flex flex-col">
                <canvas
                  id="snake-canvas"
                  phx-hook="SnakeCanvas"
                  data-game-state={Jason.encode!(serialize_game_state(@game_state))}
                  data-player-id={@player_id}
                  class="border-4 border-gray-700 rounded"
                  width="800"
                  height="600"
                >
                </canvas>
              </div>

              <%# Player 2 Panel (Right Column) - matches arena height %>
              <div class="w-48 flex flex-col" style="height: 608px;">
                <div class="text-center mb-2">
                  <div class="text-red-400 font-semibold text-lg">
                    Player 2
                    <%= if @player_id == @game_state.player2_id do %>
                      <span class="text-xs text-gray-400">(You)</span>
                    <% end %>
                  </div>
                  <div class="text-4xl font-bold text-red-300"><%= @game_state.player2_score %></div>
                </div>
                <%# Character Description %>
                <div class="text-xs text-center mb-1 px-2">
                  <span class="text-gray-400"><%= character_description(@game_state.player2_asshole_factor) %></span>
                </div>
                <%# Personality Indicator %>
                <div class="text-xs text-gray-500 text-center mb-2">
                  <%= asshole_indicator(@game_state.player2_asshole_factor) %>
                </div>
                <%# Event Feed - fills remaining height %>
                <div class="flex-1 bg-gray-800 rounded-lg p-3 flex flex-col overflow-hidden">
                  <div class="text-xs text-gray-500 mb-2 uppercase tracking-wide">Events</div>
                  <div class="flex-1 overflow-y-auto flex flex-col-reverse font-mono text-sm">
                    <%= for event <- @game_state.player2_events do %>
                      <div class="text-red-300 truncate py-0.5"><%= format_event(event) %></div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <%# Game Commentary/Feedback/Result (Bottom) %>
            <div class="mt-4 text-center">
              <%= if @game_state.game_status == :finished do %>
                <div class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-3xl font-bold mb-4">
                    <%= cond do %>
                      <% @game_state.winner == :draw -> %>
                        🤝 Draw! 🤝
                      <% @game_state.winner == @player_id -> %>
                        🎉 You Win! 🎉
                      <% true -> %>
                        💀 Game Over 💀
                    <% end %>
                  </h2>
                  <button
                    phx-click="join_queue"
                    class="bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-6 rounded-lg"
                  >
                    Play Again
                  </button>
                </div>
              <% else %>
                <div class="text-gray-400">
                  AI-controlled snakes battling it out
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <script>
      document.addEventListener("keydown", (event) => {
        const key = event.key;
        if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(key)) {
          event.preventDefault();
          window.dispatchEvent(new CustomEvent("phx:key_press", {
            detail: { key: key }
          }));
        }
      });

      window.addEventListener("phx:key_press", (event) => {
        const liveSocket = window.liveSocket;
        if (liveSocket && liveSocket.main) {
          liveSocket.execJS(liveSocket.main.el, [["push", {
            event: "key_press",
            value: { key: event.detail.key }
          }]]);
        }
      });
    </script>
    """
  end

  ## Private Functions

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # Normalize game state to use atom keys for template access
  defp normalize_game_state(state) when is_map(state) do
    # Handle game_status conversion (string "running"/"finished" to atom)
    game_status = case get_field(state, :game_status) do
      "running" -> :running
      "finished" -> :finished
      status when is_atom(status) -> status
      _ -> :running
    end

    # Handle winner (could be "nil" string, "draw" string, or actual player_id)
    winner = case get_field(state, :winner) do
      "nil" -> nil
      nil -> nil
      "draw" -> :draw
      :draw -> :draw
      w -> w
    end

    %{
      game_id: get_field(state, :game_id),
      player1_id: get_field(state, :player1_id),
      player2_id: get_field(state, :player2_id),
      player1_snake: get_field(state, :player1_snake) || [],
      player2_snake: get_field(state, :player2_snake) || [],
      player1_score: get_field(state, :player1_score) || 0,
      player2_score: get_field(state, :player2_score) || 0,
      food_position: get_field(state, :food_position) || {0, 0},
      game_status: game_status,
      winner: winner,
      player1_events: get_field(state, :player1_events) || [],
      player2_events: get_field(state, :player2_events) || [],
      player1_asshole_factor: get_field(state, :player1_asshole_factor) || 0,
      player2_asshole_factor: get_field(state, :player2_asshole_factor) || 0
    }
  end

  defp key_to_direction("ArrowUp"), do: :up
  defp key_to_direction("ArrowDown"), do: :down
  defp key_to_direction("ArrowLeft"), do: :left
  defp key_to_direction("ArrowRight"), do: :right
  defp key_to_direction(_), do: nil

  # Format event for display
  defp format_event(%{"type" => "food", "value" => score}), do: "+#{score}"
  defp format_event(%{"type" => "turn", "value" => "up"}), do: "^ UP"
  defp format_event(%{"type" => "turn", "value" => "down"}), do: "v DOWN"
  defp format_event(%{"type" => "turn", "value" => "left"}), do: "< LEFT"
  defp format_event(%{"type" => "turn", "value" => "right"}), do: "> RIGHT"
  defp format_event(%{"type" => "collision", "value" => "wall"}), do: "WALL!"
  defp format_event(%{"type" => "collision", "value" => "self"}), do: "SELF!"
  defp format_event(%{"type" => "collision", "value" => "snake"}), do: "SNAKE!"
  defp format_event(%{"type" => "collision", "value" => "head_to_head"}), do: "CRASH!"
  defp format_event(%{"type" => "win", "value" => _}), do: "WIN!"
  defp format_event(%{type: "food", value: score}), do: "+#{score}"
  defp format_event(%{type: "turn", value: "up"}), do: "^ UP"
  defp format_event(%{type: "turn", value: "down"}), do: "v DOWN"
  defp format_event(%{type: "turn", value: "left"}), do: "< LEFT"
  defp format_event(%{type: "turn", value: "right"}), do: "> RIGHT"
  defp format_event(%{type: "collision", value: "wall"}), do: "WALL!"
  defp format_event(%{type: "collision", value: "self"}), do: "SELF!"
  defp format_event(%{type: "collision", value: "snake"}), do: "SNAKE!"
  defp format_event(%{type: "collision", value: "head_to_head"}), do: "CRASH!"
  defp format_event(%{type: "win", value: _}), do: "WIN!"
  defp format_event(_), do: "?"

  # Character description based on asshole factor
  defp character_description(factor) when is_nil(factor), do: ""
  defp character_description(factor) when factor < 20 do
    "A noble serpent who plays fair and avoids dirty tricks"
  end
  defp character_description(factor) when factor < 40 do
    "A relaxed snake, prefers food over confrontation"
  end
  defp character_description(factor) when factor < 60 do
    "Balanced fighter, will cut you off if given the chance"
  end
  defp character_description(factor) when factor < 80 do
    "Ruthless hunter, actively seeks to trap opponents"
  end
  defp character_description(_factor) do
    "Pure chaos agent, lives to make your life miserable"
  end

  # Asshole factor indicator with emoji scale
  defp asshole_indicator(factor) when is_nil(factor), do: ""
  defp asshole_indicator(factor) when factor < 20, do: "Personality: Gentleman"
  defp asshole_indicator(factor) when factor < 40, do: "Personality: Chill"
  defp asshole_indicator(factor) when factor < 60, do: "Personality: Competitive"
  defp asshole_indicator(factor) when factor < 80, do: "Personality: Aggressive"
  defp asshole_indicator(_factor), do: "Personality: Total Jerk"

  defp serialize_game_state(state) do
    # Handle both atom and string keys (from local state vs JSON)
    %{
      game_id: get_field(state, :game_id),
      player1_snake: normalize_positions(get_field(state, :player1_snake)),
      player2_snake: normalize_positions(get_field(state, :player2_snake)),
      player1_score: get_field(state, :player1_score),
      player2_score: get_field(state, :player2_score),
      food_position: normalize_position(get_field(state, :food_position)),
      game_status: get_field(state, :game_status),
      winner: get_field(state, :winner)
    }
  end

  # Get field from map with either atom or string key
  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  # Normalize position to list format [x, y]
  defp normalize_position({x, y}), do: [x, y]
  defp normalize_position([x, y]), do: [x, y]
  defp normalize_position(nil), do: [0, 0]

  # Normalize list of positions
  defp normalize_positions(nil), do: []
  defp normalize_positions(positions) when is_list(positions) do
    Enum.map(positions, &normalize_position/1)
  end
end
