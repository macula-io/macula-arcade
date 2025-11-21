defmodule MaculaArcade.Mesh.NodeManager do
  @moduledoc """
  Manages the Macula mesh connection for the arcade node.

  This GenServer:
  - Connects to the LOCAL Macula instance via process-to-process communication
  - Publishes node presence events
  - Manages the mesh client lifecycle
  - Provides access to the mesh client for game coordination

  NOTE: In Macula v0.8.9+, in-VM workloads use `connect_local/1` which communicates
  directly with the local gateway process, avoiding QUIC overhead. DHT bootstrapping
  is handled at the platform level via MACULA_BOOTSTRAP_PEERS environment variable.
  """

  use GenServer
  require Logger

  @realm "macula.arcade.dev"
  @presence_topic "arcade.node.presence"

  ## Client API

  @doc """
  Starts the NodeManager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the Macula client PID for making mesh calls.
  """
  def client do
    GenServer.call(__MODULE__, :get_client)
  end

  @doc """
  Publishes a message to a topic on the mesh.
  """
  def publish(topic, data, opts \\ %{}) do
    GenServer.call(__MODULE__, {:publish, topic, data, opts})
  end

  @doc """
  Subscribes to a topic on the mesh.
  """
  def subscribe(topic, callback) do
    GenServer.call(__MODULE__, {:subscribe, topic, callback})
  end

  @doc """
  Makes an RPC call to a service on the mesh.
  """
  def call_service(procedure, args, opts \\ %{}) do
    GenServer.call(__MODULE__, {:call_service, procedure, args, opts})
  end

  @doc """
  Advertises a service this node provides.
  """
  def advertise_service(procedure, handler, opts \\ %{}) do
    GenServer.call(__MODULE__, {:advertise_service, procedure, handler, opts})
  end

  @doc """
  Discovers subscribers to a topic via DHT query.
  Returns a list of nodes subscribed to the topic.
  """
  def discover_subscribers(topic) do
    GenServer.call(__MODULE__, {:discover_subscribers, topic})
  end

  @doc """
  Gets the node ID of this Macula client.
  """
  def get_node_id do
    GenServer.call(__MODULE__, :get_node_id)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("NodeManager starting - connecting to local Macula gateway")

    # Connect to local gateway via process-to-process communication
    connect_opts = %{
      realm: @realm
    }

    with {:ok, client} <- :macula_client.connect_local(connect_opts) do
      Logger.info("NodeManager connected to local gateway successfully")

      # Publish presence
      node_id = node() |> Atom.to_string()
      presence_data = %{
        node_id: node_id,
        timestamp: System.system_time(:second),
        type: "arcade_node"
      }

      :macula_client.publish(client, @presence_topic, presence_data)
      Logger.info("NodeManager published presence on #{@presence_topic}")

      {:ok, %{client: client, node_id: node_id}}
    else
      {:error, reason} ->
        Logger.error("NodeManager failed to connect to local gateway: #{inspect(reason)}")
        {:stop, {:connection_failed, reason}}
    end
  end

  @impl true
  def handle_call(:get_client, _from, %{client: client} = state) do
    {:reply, {:ok, client}, state}
  end

  @impl true
  def handle_call({:publish, topic, data, opts}, _from, %{client: client} = state) do
    result = :macula_client.publish(client, topic, data, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:subscribe, topic, callback}, _from, %{client: client} = state) do
    result = :macula_client.subscribe(client, topic, callback)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:call_service, procedure, args, opts}, _from, %{client: client} = state) do
    result = :macula_client.call(client, procedure, args, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:advertise_service, procedure, handler, opts}, _from, %{client: client} = state) do
    result = :macula_client.advertise(client, procedure, handler, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:discover_subscribers, topic}, _from, %{client: client} = state) do
    result = :macula_client.discover_subscribers(client, topic)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_node_id, _from, %{client: client} = state) do
    result = :macula_client.get_node_id(client)
    {:reply, result, state}
  end

  @impl true
  def terminate(_reason, %{client: client}) do
    Logger.info("NodeManager shutting down - disconnecting from mesh")
    :macula_client.disconnect(client)
    :ok
  end
end
