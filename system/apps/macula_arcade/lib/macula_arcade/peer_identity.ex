defmodule MaculaArcade.PeerIdentity do
  @moduledoc """
  Manages the identity of this peer in the mesh network.

  Each peer has a 1-to-1 relationship with a default player. When a peer starts,
  it either loads its existing player or creates a new one with a fun mnemonic name.

  The peer identity is stored both locally (SQLite) and distributed (CRDT) so that:
  - Local data survives restarts
  - Distributed data allows other peers to see this player's stats
  """

  require Logger
  alias MaculaArcade.{Repo, SnakeMaster}
  alias MaculaArcade.SnakeMaster.Player

  @doc """
  Get or create the local peer's player.

  On first run, generates a fun mnemonic name like "happy-blue-tiger".
  On subsequent runs, loads the existing player from the database.
  """
  def get_or_create_local_player do
    case get_stored_player_id() do
      nil ->
        create_local_player()

      player_id ->
        case SnakeMaster.get_player(player_id) do
          nil ->
            # Player ID stored but player doesn't exist - recreate
            Logger.warning("Stored player #{player_id} not found, creating new player")
            create_local_player()

          player ->
            Logger.info("Loaded local player: #{player.name} (#{player.id})")
            {:ok, player}
        end
    end
  end

  @doc """
  Get the current peer's player if it exists.
  """
  def get_local_player do
    case get_stored_player_id() do
      nil -> nil
      player_id -> SnakeMaster.get_player(player_id)
    end
  end

  @doc """
  Get the peer's unique identifier (hostname-based).
  """
  def peer_id do
    hostname()
  end

  @doc """
  Generate a fun mnemonic player name.
  Uses 3 words for uniqueness while staying memorable.
  Examples: "happy-blue-tiger", "swift-red-falcon"
  """
  def generate_player_name do
    MnemonicSlugs.generate_slug(3)
  end

  # Private Functions

  defp create_local_player do
    name = generate_player_name()
    Logger.info("Creating local player with name: #{name}")

    case SnakeMaster.create_player(%{name: name}) do
      {:ok, player} ->
        store_player_id(player.id)
        Logger.info("Created local player: #{player.name} (#{player.id})")
        {:ok, player}

      {:error, _changeset} ->
        # Name collision - try again with a new name
        Logger.warning("Player name collision, retrying...")
        create_local_player()
    end
  end

  defp get_stored_player_id do
    # Store player ID in a simple key-value table or use Application env
    # For now, query by checking if a player exists for this peer's hostname
    case Repo.get_by(Player, peer_id: peer_id()) do
      nil -> nil
      player -> player.id
    end
  rescue
    # If peer_id column doesn't exist yet, fall back to nil
    _ -> nil
  end

  defp store_player_id(player_id) do
    # Update the player record with this peer's ID
    player = SnakeMaster.get_player!(player_id)
    SnakeMaster.update_player(player, %{peer_id: peer_id()})
  rescue
    # If peer_id column doesn't exist, log warning
    e ->
      Logger.warning("Could not store peer_id: #{inspect(e)}")
      :ok
  end

  defp hostname do
    case System.get_env("MACULA_HOSTNAME") do
      nil ->
        {:ok, hostname} = :inet.gethostname()
        to_string(hostname)

      hostname ->
        hostname
    end
  end
end
