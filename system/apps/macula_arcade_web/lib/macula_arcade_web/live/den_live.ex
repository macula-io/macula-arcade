defmodule MaculaArcadeWeb.DenLive do
  @moduledoc """
  The Den - where SnakeMasters manage their snakes.

  Features:
  - View all owned snakes with stats
  - Create new snakes with personality customization
  - Send snakes to the Snake Pit (PvP)
  - Send snakes to the Gym (TWEANN training - future)
  """

  use MaculaArcadeWeb, :live_view
  require Logger

  alias MaculaArcade.SnakeMaster
  alias MaculaArcade.SnakeMaster.Snake

  # Import extracted components
  import MaculaArcadeWeb.Components.Snake.SnakeList
  import MaculaArcadeWeb.Components.Snake.SnakeDetail
  import MaculaArcadeWeb.Components.Snake.SnakeCreationForm

  alias MaculaArcade.SnakeMaster.Auth

  @max_snakes 5

  @impl true
  def mount(params, session, socket) do
    # Get player from params (priority) or session (fallback)
    player =
      case params do
        %{"player_id" => player_id} ->
          Auth.get_player(player_id)

        _ ->
          # Fallback to session-based name
          player_name = Map.get(session, "player_name", generate_player_name())
          {:ok, player} = Auth.get_or_create_player(player_name)
          player
      end

    case player do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Player not found")
         |> redirect(to: ~p"/login")}

      player ->
        snakes = SnakeMaster.list_snakes_for_player(player.id)

        socket =
          socket
          |> assign(:player, player)
          |> assign(:snakes, snakes)
          |> assign(:max_snakes, @max_snakes)
          |> assign(:view, :den)
          |> assign(:selected_snake, nil)
          |> assign(:creating_snake, false)
          |> assign(:new_snake_form, default_snake_form())

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white p-4">
      <!-- Header -->
      <div class="max-w-4xl mx-auto mb-6">
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold text-green-400">The Den</h1>
            <p class="text-gray-400">Welcome, {@player.name}</p>
          </div>
          <div class="flex items-center gap-4">
            <div class="text-yellow-400">
              <span class="text-2xl">🪙</span> {@player.coins}
            </div>
            <div class="text-purple-400">
              <span class="text-2xl">⭐</span> {@player.reputation}
            </div>
            <.link
              navigate={~p"/snake?player_id=#{@player.id}"}
              class="px-3 py-1 bg-green-600 hover:bg-green-500 rounded text-sm"
            >
              Play
            </.link>
            <.link
              href={~p"/logout"}
              class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
            >
              Logout
            </.link>
          </div>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="max-w-4xl mx-auto">
        <%= if @creating_snake do %>
          <.snake_creation_form form={@new_snake_form} />
        <% else %>
          <%= if @selected_snake do %>
            <.snake_detail snake={@selected_snake} />
          <% else %>
            <.snake_list snakes={@snakes} max_snakes={@max_snakes} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("start_create_snake", _params, socket) do
    {:noreply, assign(socket, :creating_snake, true)}
  end

  @impl true
  def handle_event("cancel_create", _params, socket) do
    socket =
      socket
      |> assign(:creating_snake, false)
      |> assign(:new_snake_form, default_snake_form())

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_form", params, socket) do
    current_form = socket.assigns.new_snake_form

    form = %{
      name: params["name"] || current_form.name,
      tweann_preset: current_form.tweann_preset,
      tweann_mutation_rate:
        parse_float(params["tweann_mutation_rate"], current_form.tweann_mutation_rate),
      tweann_memory_depth:
        parse_int(params["tweann_memory_depth"], current_form.tweann_memory_depth),
      tweann_risk_tolerance:
        parse_int(params["tweann_risk_tolerance"], current_form.tweann_risk_tolerance),
      tweann_exploration_rate:
        parse_int(params["tweann_exploration_rate"], current_form.tweann_exploration_rate),
      show_advanced_tweann: current_form.show_advanced_tweann,
      color_primary: params["color_primary"] || current_form.color_primary,
      color_secondary: params["color_secondary"] || current_form.color_secondary
    }

    # If any TWEANN parameter was manually changed, switch to custom preset
    form =
      if params["tweann_mutation_rate"] || params["tweann_memory_depth"] ||
           params["tweann_risk_tolerance"] || params["tweann_exploration_rate"] do
        %{form | tweann_preset: "custom"}
      else
        form
      end

    {:noreply, assign(socket, :new_snake_form, form)}
  end

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    # Apply preset values to form
    config = Snake.preset_config(preset)

    form =
      socket.assigns.new_snake_form
      |> Map.put(:tweann_preset, preset)
      |> Map.put(:tweann_mutation_rate, config.mutation_rate)
      |> Map.put(:tweann_memory_depth, config.memory_depth)
      |> Map.put(:tweann_risk_tolerance, config.risk_tolerance)
      |> Map.put(:tweann_exploration_rate, config.exploration_rate)

    {:noreply, assign(socket, :new_snake_form, form)}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    form = socket.assigns.new_snake_form
    form = %{form | show_advanced_tweann: !form.show_advanced_tweann}
    {:noreply, assign(socket, :new_snake_form, form)}
  end

  @impl true
  def handle_event("create_snake", _params, socket) do
    form = socket.assigns.new_snake_form

    attrs = %{
      name: form.name,
      tweann_preset: form.tweann_preset,
      tweann_mutation_rate: form.tweann_mutation_rate,
      tweann_memory_depth: form.tweann_memory_depth,
      tweann_risk_tolerance: form.tweann_risk_tolerance,
      tweann_exploration_rate: form.tweann_exploration_rate,
      color_primary: form.color_primary,
      color_secondary: form.color_secondary
    }

    case SnakeMaster.create_snake(socket.assigns.player.id, attrs) do
      {:ok, _snake} ->
        snakes = SnakeMaster.list_snakes_for_player(socket.assigns.player.id)

        socket =
          socket
          |> assign(:snakes, snakes)
          |> assign(:creating_snake, false)
          |> assign(:new_snake_form, default_snake_form())
          |> put_flash(:info, "#{form.name} has hatched!")

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to create snake: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("select_snake", %{"id" => id}, socket) do
    snake = SnakeMaster.get_snake(id)
    {:noreply, assign(socket, :selected_snake, snake)}
  end

  @impl true
  def handle_event("back_to_list", _params, socket) do
    {:noreply, assign(socket, :selected_snake, nil)}
  end

  @impl true
  def handle_event("send_to_pit", %{"id" => id}, socket) do
    _snake = SnakeMaster.get_snake!(id)

    # Navigate to snake game with this snake
    {:noreply, push_navigate(socket, to: ~p"/snake?snake_id=#{id}")}
  end

  @impl true
  def handle_event("send_to_gym", %{"id" => _id}, socket) do
    {:noreply, put_flash(socket, :info, "Training coming soon!")}
  end

  @impl true
  def handle_event("delete_snake", %{"id" => id}, socket) do
    snake = SnakeMaster.get_snake!(id)

    case SnakeMaster.delete_snake(snake) do
      {:ok, _} ->
        snakes = SnakeMaster.list_snakes_for_player(socket.assigns.player.id)

        socket =
          socket
          |> assign(:snakes, snakes)
          |> assign(:selected_snake, nil)
          |> put_flash(:info, "#{snake.name} has been released")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to release snake")}
    end
  end

  # Helpers

  defp generate_player_name do
    adjectives = ~w(Swift Sneaky Cunning Fierce Sly Mighty Deadly Venomous)
    nouns = ~w(Master Tamer Handler Whisperer Charmer Keeper Warden)

    adj = Enum.random(adjectives)
    noun = Enum.random(nouns)
    num = :rand.uniform(999)

    "#{adj}#{noun}#{num}"
  end

  defp default_snake_form do
    config = Snake.preset_config("balanced")

    %{
      name: "",
      tweann_preset: "balanced",
      tweann_mutation_rate: config.mutation_rate,
      tweann_memory_depth: config.memory_depth,
      tweann_risk_tolerance: config.risk_tolerance,
      tweann_exploration_rate: config.exploration_rate,
      show_advanced_tweann: false,
      color_primary: "#22c55e",
      color_secondary: "#16a34a"
    }
  end

  defp parse_int(nil, default), do: default

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {val, _} -> val
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_float(nil, default), do: default

  defp parse_float(str, default) when is_binary(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> default
    end
  end

  defp parse_float(val, _default) when is_float(val), do: val
  defp parse_float(val, _default) when is_integer(val), do: val / 1

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
