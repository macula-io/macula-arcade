defmodule MaculaArcade.Mesh do
  @moduledoc """
  Macula mesh connection helpers for MaculaArcade.

  This module provides a simple interface for accessing the Macula platform.
  The connection is established once at application startup and the client PID
  is stored in persistent_term for fast, constant-time access.

  ## Usage

      # Get the macula client PID
      client = MaculaArcade.Mesh.client()

      # Make direct calls to macula
      :macula.publish(client, "arcade.events", %{type: "test"})
      {:ok, ref} = :macula.subscribe(client, "arcade.events", callback)
  """

  require Logger

  @realm "macula.arcade.dev"
  @presence_topic "arcade.node.presence"
  @client_key {__MODULE__, :client}

  @doc """
  Connects to the local Macula platform and stores the client PID.

  Called automatically during application startup.
  Registers with Platform Layer for distributed coordination.
  """
  def connect do
    Logger.info("[Mesh] Connecting to local Macula platform (realm: #{@realm})")

    case :macula.connect_local(%{realm: @realm}) do
      {:ok, client} ->
        Logger.info("[Mesh] Connected to Macula platform, client: #{inspect(client)}")

        # Store client PID in persistent_term for fast access
        :persistent_term.put(@client_key, client)

        # Register with Platform Layer (v0.10.0+)
        case :macula.register_workload(client, %{
          workload_name: "macula_arcade",
          workload_type: "game_server",
          capabilities: ["matchmaking", "game_hosting"]
        }) do
          {:ok, platform_info} ->
            Logger.info("[Mesh] Registered with Platform Layer: #{inspect(platform_info)}")
            Logger.info("[Mesh] Leader node: #{inspect(platform_info.leader_node)}")
            Logger.info("[Mesh] Cluster size: #{platform_info.cluster_size}")

          {:error, reason} ->
            Logger.warning("[Mesh] Failed to register with Platform Layer: #{inspect(reason)}")
        end

        # Publish initial presence
        node_id = node() |> Atom.to_string()
        presence_data = %{
          node_id: node_id,
          timestamp: System.system_time(:second),
          type: "arcade_node"
        }

        :macula.publish(client, @presence_topic, presence_data)
        Logger.info("[Mesh] Published presence on #{@presence_topic}")

        {:ok, client}

      {:error, reason} = error ->
        Logger.error("[Mesh] Failed to connect to Macula: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Gets the Macula client PID.

  Returns the client PID or raises if not connected.

  ## Examples

      client = MaculaArcade.Mesh.client()
      :macula.publish(client, "topic", %{data: "test"})
  """
  def client do
    case :persistent_term.get(@client_key, nil) do
      nil ->
        raise """
        Macula client not connected!
        Ensure MaculaArcade.Mesh.connect/0 was called during application startup.
        """

      client when is_pid(client) ->
        client
    end
  end

  @doc """
  Gets the Macula client PID safely, returning {:ok, pid} or {:error, reason}.

  ## Examples

      case MaculaArcade.Mesh.get_client() do
        {:ok, client} -> :macula.publish(client, "topic", data)
        {:error, :not_connected} -> Logger.error("Not connected to mesh")
      end
  """
  def get_client do
    case :persistent_term.get(@client_key, nil) do
      nil -> {:error, :not_connected}
      client when is_pid(client) -> {:ok, client}
    end
  end

  @doc """
  Gets the current Raft leader node ID.

  Returns {:ok, node_id} or {:error, :no_leader}.
  """
  def get_leader do
    client = client()
    :macula.get_leader(client)
  end

  @doc """
  Subscribes to leader change notifications.

  Callback will be called with %{old_leader: binary(), new_leader: binary()}.
  """
  def subscribe_leader_changes(callback) do
    client = client()
    :macula.subscribe_leader_changes(client, callback)
  end

  @doc """
  Proposes a CRDT update for distributed shared state.

  Uses LWW-Register (Last-Write-Wins) by default.
  """
  def propose_crdt_update(key, value, opts \\ %{}) do
    client = client()
    :macula.propose_crdt_update(client, key, value, opts)
  end

  @doc """
  Reads a CRDT value from distributed shared state.
  """
  def read_crdt(key, opts \\ %{}) do
    client = client()
    :macula.read_crdt(client, key)
  end
end
