defmodule MaculaArcade.Mesh.NodeManager do
  @moduledoc """
  Manages the Macula mesh connection for the arcade node.

  This GenServer:
  - Connects to the Macula mesh on startup
  - Publishes node presence events
  - Manages the mesh client lifecycle
  - Provides access to the mesh client for game coordination
  """

  use GenServer
  require Logger

  @realm "macula.arcade"
  @presence_topic "arcade.node.presence"

  defp mesh_url do
    System.get_env("MACULA_BOOTSTRAP_REGISTRY", "https://arcade-gateway:4433")
  end

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

  ## Server Callbacks

  @impl true
  def init(_opts) do
    gateway_url = mesh_url()
    Logger.info("NodeManager starting - connecting to Macula mesh at #{gateway_url}")

    # Connect to mesh
    connect_opts = %{
      realm: @realm,
      timeout: 10_000
    }

    with {:ok, client} <- :macula_client.connect(gateway_url, connect_opts) do
      Logger.info("NodeManager connected to mesh successfully")

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
        Logger.error("NodeManager failed to connect to mesh: #{inspect(reason)}")
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
  def terminate(_reason, %{client: client}) do
    Logger.info("NodeManager shutting down - disconnecting from mesh")
    :macula_client.disconnect(client)
    :ok
  end
end
