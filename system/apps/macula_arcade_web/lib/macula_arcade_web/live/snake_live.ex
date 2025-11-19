defmodule MaculaArcadeWeb.SnakeLive do
  @moduledoc """
  LiveView for Snake Duel game (1v1).

  Handles:
  - Player registration and matchmaking
  - Game state display
  - Player input (arrow keys)
  - Real-time updates from Macula mesh
  """

  use MaculaArcadeWeb, :live_view
  require Logger
  alias MaculaArcade.Games.Coordinator
  alias MaculaArcade.Mesh.NodeManager

  @impl true
  def mount(_params, _session, socket) do
    player_id = generate_player_id()

    # Subscribe to game start events early (before user clicks Find Game)
    # This ensures we don't miss the event due to race conditions

    # Subscribe via Phoenix PubSub (for single-container)
    Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.start")

    # Subscribe via Macula mesh (for multi-container)
    case NodeManager.subscribe("arcade.game.start", fn event_data ->
           # Convert mesh event to LiveView message
           send(self(), {:game_started, event_data})
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
      NodeManager.publish(topic, %{
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

      # Subscribe to game state updates via mesh (for multi-container)
      case NodeManager.subscribe("arcade.game.#{game_id}.state", fn state_data ->
             send(self(), {:game_state_update, state_data})
             :ok
           end) do
        {:ok, _sub_ref} -> :ok
        {:error, :not_connected} -> Logger.warn("Cannot subscribe to game state via mesh - not connected")
      end

      # Also subscribe via Phoenix PubSub (for single-container)
      Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.#{game_id}.state")

      # Subscribe to player input via mesh (for multi-container)
      case NodeManager.subscribe("arcade.game.#{game_id}.input", fn input_data ->
             send(self(), {:player_input, input_data})
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
          player1_snake: [],
          player2_snake: [],
          player1_score: 0,
          player2_score: 0,
          food_position: {0, 0},
          game_status: :running,
          winner: nil
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_state_update, game_state}, socket) do
    # Log at info level every 60 updates (once per second at 60 FPS)
    if rem(:erlang.unique_integer([:positive]), 60) == 0 do
      Logger.info("SnakeLive received game_state_update for game #{inspect(game_state[:game_id] || game_state["game_id"])}")
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
            <div class="flex justify-between mb-4 text-xl">
              <div class="flex-1">
                <span class="text-blue-400">Player 1:</span>
                <span class="ml-2 font-bold"><%= @game_state.player1_score %></span>
              </div>
              <div class="flex-1 text-right">
                <span class="text-red-400">Player 2:</span>
                <span class="ml-2 font-bold"><%= @game_state.player2_score %></span>
              </div>
            </div>

            <canvas
              id="snake-canvas"
              phx-hook="SnakeCanvas"
              data-game-state={Jason.encode!(serialize_game_state(@game_state))}
              class="border-4 border-gray-700 mx-auto"
              width="800"
              height="600"
            >
            </canvas>

            <div class="text-center mt-4 text-gray-400">
              Use arrow keys to move
            </div>

            <%= if @game_state.game_status == :finished do %>
              <div class="text-center mt-8">
                <h2 class="text-3xl font-bold mb-4">
                  <%= if @game_state.winner == @player_id do %>
                    🎉 You Win! 🎉
                  <% else %>
                    💀 Game Over 💀
                  <% end %>
                </h2>
                <button
                  phx-click="join_queue"
                  class="bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
                >
                  Play Again
                </button>
              </div>
            <% end %>
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

  defp key_to_direction("ArrowUp"), do: :up
  defp key_to_direction("ArrowDown"), do: :down
  defp key_to_direction("ArrowLeft"), do: :left
  defp key_to_direction("ArrowRight"), do: :right
  defp key_to_direction(_), do: nil

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
