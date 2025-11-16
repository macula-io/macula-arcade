defmodule MaculaArcadeWeb.SnakeLive do
  @moduledoc """
  LiveView for Snake Battle Royale game.

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

    # Join matchmaking queue
    Coordinator.join_queue(socket.assigns.player_id)

    socket =
      socket
      |> assign(:waiting, true)
      |> assign(:status, :waiting)

    {:noreply, socket}
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

    # Check if this player is in the game
    if player_id in [p1, p2] do
      Logger.info("Player #{player_id} matched in game #{game_id}")

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
    socket = assign(socket, :game_state, game_state)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_input, %{player_id: _player_id, direction: _direction}}, socket) do
    # Input handled by backend GameServer
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-4xl font-bold text-center mb-8">
          Snake Battle Royale
        </h1>

        <%= if @status == :lobby do %>
          <div class="text-center">
            <p class="text-xl mb-4">Welcome to Snake Battle Royale!</p>
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
    %{
      game_id: state.game_id,
      player1_snake: Enum.map(state.player1_snake, &Tuple.to_list/1),
      player2_snake: Enum.map(state.player2_snake, &Tuple.to_list/1),
      player1_score: state.player1_score,
      player2_score: state.player2_score,
      food_position: Tuple.to_list(state.food_position),
      game_status: state.game_status,
      winner: state.winner
    }
  end
end
