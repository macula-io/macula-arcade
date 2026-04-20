defmodule MaculaArcade.Games.BotGuest do
  @moduledoc """
  Lightweight bot guest for Quick Games.

  Spawned on-demand when a human player wants a Quick Game.
  Immediately subscribes to game state, signals ready, and participates
  as an eager guest until the game ends.

  Unlike BotClient (which manages queue participation), BotGuest is:
  - Created for a specific game
  - Automatically signals ready
  - Dies when game ends
  - Lightweight and stateless beyond game subscription
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh

  defstruct [
    :player_id,
    :game_id,
    :sub_ref,
    :ready_sent
  ]

  ## Client API

  @doc """
  Start a bot guest for a specific game.
  The bot will immediately subscribe and signal ready.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Spawn a bot guest under DynamicSupervisor for a Quick Game.
  Returns {:ok, pid, bot_id} or {:error, reason}
  """
  def spawn_for_game(game_id) do
    bot_id = generate_bot_id()

    case DynamicSupervisor.start_child(
           MaculaArcade.BotGuestSupervisor,
           {__MODULE__, game_id: game_id, player_id: bot_id}
         ) do
      {:ok, pid} ->
        Logger.info("BotGuest spawned: pid=#{inspect(pid)}, bot_id=#{bot_id}, game=#{game_id}")
        {:ok, pid, bot_id}

      {:error, reason} ->
        Logger.error("Failed to spawn BotGuest: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    player_id = Keyword.fetch!(opts, :player_id)

    Logger.info("BotGuest starting: player_id=#{player_id}, game_id=#{game_id}")

    state = %__MODULE__{
      player_id: player_id,
      game_id: game_id,
      sub_ref: nil,
      ready_sent: false
    }

    # Subscribe and signal ready immediately
    send(self(), :subscribe_and_ready)

    {:ok, state}
  end

  @impl true
  def handle_info(:subscribe_and_ready, state) do
    client = Mesh.client()
    game_id = state.game_id
    player_id = state.player_id

    # Subscribe to game state updates
    state_topic = "arcade.game.#{game_id}.state"

    sub_result =
      :macula.subscribe(client, state_topic, fn game_state ->
        send(self(), {:game_state, game_state})
        :ok
      end)

    state =
      case sub_result do
        {:ok, sub_ref} ->
          Logger.info("BotGuest #{player_id} subscribed to #{state_topic}")
          %{state | sub_ref: sub_ref}

        {:error, reason} ->
          Logger.warning("BotGuest #{player_id} failed to subscribe: #{inspect(reason)}")
          state
      end

    # Signal ready immediately - bot is always eager!
    ready_topic = "arcade.game.#{game_id}.ready"
    :macula.publish(client, ready_topic, %{player_id: player_id})
    Logger.info("BotGuest #{player_id} sent ready signal to #{ready_topic}")

    {:noreply, %{state | ready_sent: true}}
  end

  @impl true
  def handle_info({:game_state, game_state}, state) do
    game_status = game_state[:game_status] || game_state["game_status"]

    cond do
      game_status in [:finished, "finished"] ->
        winner = game_state[:winner] || game_state["winner"]
        Logger.info("BotGuest #{state.player_id} game finished, winner: #{inspect(winner)}")

        # Cleanup and stop - game is over
        cleanup(state)
        {:stop, :normal, state}

      game_status in [:countdown, "countdown"] ->
        countdown = game_state[:countdown] || game_state["countdown"]
        Logger.debug("BotGuest #{state.player_id} countdown: #{countdown}")
        {:noreply, state}

      game_status in [:running, "running"] ->
        # Game is running - bot observes (AI logic in GameServer handles movement)
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("BotGuest #{state.player_id} received: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("BotGuest #{state.player_id} terminating: #{inspect(reason)}")
    cleanup(state)
    :ok
  end

  ## Private Functions

  defp cleanup(state) do
    if state.sub_ref do
      client = Mesh.client()
      :macula.unsubscribe(client, state.sub_ref)
    end
  end

  defp generate_bot_id do
    "bot_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end
end
