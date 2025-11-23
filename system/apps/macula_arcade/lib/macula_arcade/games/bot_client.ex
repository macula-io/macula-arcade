defmodule MaculaArcade.Games.BotClient do
  @moduledoc """
  Headless bot client for automated game participation.

  Automatically joins the matchmaking queue on startup and participates
  in games without requiring a browser/LiveView connection.

  Used for scalability testing and filling games when human players
  are waiting.
  """

  use GenServer
  require Logger
  alias MaculaArcade.Games.Coordinator
  alias MaculaArcade.Games.Snake.GameServer
  alias MaculaArcade.Mesh

  defstruct [
    :player_id,
    :game_id,
    :game_pid,
    :status  # :idle | :waiting | :playing
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Manually trigger joining the queue (for testing).
  """
  def join_queue(pid) do
    GenServer.cast(pid, :join_queue)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    player_id = Keyword.get(opts, :player_id, generate_player_id())
    auto_join = Keyword.get(opts, :auto_join, true)

    Logger.info("BotClient starting with player_id=#{player_id}, auto_join=#{auto_join}")

    state = %__MODULE__{
      player_id: player_id,
      status: :idle
    }

    # Subscribe to game start events via Phoenix PubSub
    Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.start")

    # Subscribe via Macula mesh
    client = Mesh.client()
    case :macula.subscribe(client, "arcade.game.start", fn event_data ->
           send(self(), {:game_started, event_data})
           :ok
         end) do
      {:ok, _sub_ref} ->
        Logger.info("BotClient subscribed to game start events via mesh")
      {:error, reason} ->
        Logger.warning("BotClient cannot subscribe via mesh: #{inspect(reason)}")
    end

    # Auto-join queue after a short delay (let system stabilize)
    if auto_join do
      Process.send_after(self(), :auto_join, 2_000)
    end

    {:ok, state}
  end

  @impl true
  def handle_cast(:join_queue, state) do
    {:noreply, do_join_queue(state)}
  end

  @impl true
  def handle_info(:auto_join, state) do
    {:noreply, do_join_queue(state)}
  end

  @impl true
  def handle_info({:game_started, %{game_id: game_id, player1_id: p1, player2_id: p2}}, state) do
    player_id = state.player_id

    if player_id in [p1, p2] do
      Logger.info("BotClient #{player_id} matched in game #{game_id}")

      # Subscribe to game state updates
      Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.#{game_id}.state")

      # Start local GameServer (same as guest peer does)
      {:ok, game_pid} =
        DynamicSupervisor.start_child(
          MaculaArcade.GameSupervisor,
          {GameServer, [game_id: game_id]}
        )

      {:ok, ^game_id} = GameServer.start_game(game_pid, p1, p2)

      Logger.info("BotClient started local GameServer for game #{game_id}")

      {:noreply, %{state | game_id: game_id, game_pid: game_pid, status: :playing}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:game_state_update, game_state}, state) do
    # Bot receives game state updates
    # Could log or track stats here
    game_status = game_state[:game_status] || game_state["game_status"]

    if game_status == :finished or game_status == "finished" do
      winner = game_state[:winner] || game_state["winner"]
      Logger.info("BotClient #{state.player_id} game finished, winner: #{inspect(winner)}")

      # Re-join queue for another game after a delay
      Process.send_after(self(), :auto_join, 3_000)

      {:noreply, %{state | status: :idle, game_id: nil, game_pid: nil}}
    else
      {:noreply, state}
    end
  end

  # Catch-all for unexpected formats
  @impl true
  def handle_info({:game_started, data}, state) do
    Logger.debug("BotClient received game_started with unexpected format: #{inspect(data)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("BotClient received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp do_join_queue(%{status: :waiting} = state) do
    Logger.debug("BotClient #{state.player_id} already waiting")
    state
  end

  defp do_join_queue(%{status: :playing} = state) do
    Logger.debug("BotClient #{state.player_id} already in game")
    state
  end

  defp do_join_queue(state) do
    Logger.info("BotClient #{state.player_id} joining queue")

    case Coordinator.register_player(state.player_id) do
      {:ok, %{queue_position: pos}} ->
        Logger.info("BotClient #{state.player_id} registered at position #{pos}")
        %{state | status: :waiting}

      {:error, reason} ->
        Logger.warning("BotClient #{state.player_id} failed to register: #{inspect(reason)}")
        # Retry after delay
        Process.send_after(self(), :auto_join, 5_000)
        state
    end
  end

  defp generate_player_id do
    "bot_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))
  end
end
