defmodule MaculaArcade.PeerInit do
  @moduledoc """
  Initializes this peer's identity and registers it with the distributed leaderboard.

  This GenServer runs once at startup to:
  1. Create or load the local player (via PeerIdentity)
  2. Register the player in the distributed leaderboard (CRDT)
  3. Register any existing snakes in the distributed leaderboard
  """

  use GenServer
  require Logger
  alias MaculaArcade.{PeerIdentity, DistributedLeaderboard, SnakeMaster}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get the local player that was initialized at startup.
  """
  def get_local_player do
    GenServer.call(__MODULE__, :get_local_player)
  end

  @impl true
  def init(_opts) do
    # Schedule initialization after a short delay to ensure Repo is ready
    Process.send_after(self(), :initialize, 100)
    {:ok, %{player: nil, initialized: false}}
  end

  @impl true
  def handle_info(:initialize, state) do
    case initialize_peer() do
      {:ok, player} ->
        Logger.info("Peer initialized with player: #{player.name} (#{player.id})")
        {:noreply, %{state | player: player, initialized: true}}

      {:error, reason} ->
        Logger.error("Failed to initialize peer: #{inspect(reason)}")
        # Retry after a delay
        Process.send_after(self(), :initialize, 5000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_local_player, _from, state) do
    {:reply, state.player, state}
  end

  defp initialize_peer do
    with {:ok, player} <- PeerIdentity.get_or_create_local_player(),
         :ok <- register_player_in_leaderboard(player),
         :ok <- register_snakes_in_leaderboard(player) do
      {:ok, player}
    end
  end

  defp register_player_in_leaderboard(player) do
    case DistributedLeaderboard.register_player(player) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not register player in distributed leaderboard: #{inspect(reason)}")
        # Don't fail initialization - leaderboard registration is best-effort
        :ok
    end
  end

  defp register_snakes_in_leaderboard(player) do
    player.snakes
    |> Enum.each(fn snake ->
      case DistributedLeaderboard.register_snake(snake, player) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Could not register snake #{snake.name} in distributed leaderboard: #{inspect(reason)}"
          )
      end
    end)

    :ok
  rescue
    # Handle case where snakes association isn't loaded
    _ ->
      snakes = SnakeMaster.list_player_snakes(player.id)

      Enum.each(snakes, fn snake ->
        DistributedLeaderboard.register_snake(snake, player)
      end)

      :ok
  end
end
