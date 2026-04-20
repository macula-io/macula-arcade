defmodule MaculaArcadeWeb.AuthLive do
  @moduledoc """
  LiveView for player authentication (login and registration).

  Supports:
  - Login with username/password
  - Registration with username/password
  - Player switching on shared nodes
  """

  use MaculaArcadeWeb, :live_view

  alias MaculaArcade.SnakeMaster.Auth

  @impl true
  def mount(_params, session, socket) do
    # Check if already logged in
    current_player_id = Map.get(session, "player_id")

    socket =
      socket
      |> assign(:current_player_id, current_player_id)
      |> assign(:mode, :login)
      |> assign(:form_data, %{name: "", password: "", password_confirmation: ""})
      |> assign(:error, nil)
      |> assign(:players, list_local_players())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white flex items-center justify-center p-4">
      <div class="max-w-md w-full">
        <%!-- Logo/Title --%>
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-green-400 mb-2">MACULA ARCADE</h1>
          <p class="text-gray-400">Snake Duel - Local Authentication</p>
        </div>

        <%!-- Quick Player Switch (if players exist) --%>
        <%= if @players != [] do %>
          <div class="bg-gray-800 rounded-lg p-4 mb-6">
            <h3 class="text-sm text-gray-400 mb-3">Quick Switch</h3>
            <div class="flex flex-wrap gap-2">
              <%= for player <- @players do %>
                <button
                  phx-click="select_player"
                  phx-value-id={player.id}
                  class={"px-3 py-2 rounded-lg text-sm font-mono transition " <>
                    if(player.password_hash, do: "bg-blue-900/50 text-blue-400 border border-blue-700 hover:bg-blue-800/50", else: "bg-gray-700 text-gray-400 hover:bg-gray-600")}
                >
                  {player.name}
                  <%= if player.password_hash do %>
                    <span class="ml-1 text-xs">🔐</span>
                  <% end %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Mode Toggle --%>
        <div class="flex mb-6">
          <button
            phx-click="set_mode"
            phx-value-mode="login"
            class={"flex-1 py-3 text-center font-semibold transition " <>
              if(@mode == :login, do: "bg-green-600 text-white", else: "bg-gray-700 text-gray-400 hover:bg-gray-600")}
          >
            LOGIN
          </button>
          <button
            phx-click="set_mode"
            phx-value-mode="register"
            class={"flex-1 py-3 text-center font-semibold transition " <>
              if(@mode == :register, do: "bg-green-600 text-white", else: "bg-gray-700 text-gray-400 hover:bg-gray-600")}
          >
            REGISTER
          </button>
        </div>

        <%!-- Form --%>
        <form
          phx-submit={if @mode == :login, do: "login", else: "register"}
          class="bg-gray-800 rounded-lg p-6"
        >
          <%!-- Error Message --%>
          <%= if @error do %>
            <div class="bg-red-900/50 border border-red-700 text-red-400 px-4 py-2 rounded-lg mb-4">
              {@error}
            </div>
          <% end %>

          <%!-- Username --%>
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2">Username</label>
            <input
              type="text"
              name="name"
              value={@form_data.name}
              phx-change="update_form"
              placeholder="Enter username..."
              class="w-full px-4 py-3 bg-gray-700 rounded-lg border border-gray-600 focus:border-green-500 focus:outline-none"
              autocomplete="username"
              required
            />
          </div>

          <%!-- Password --%>
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2">Password</label>
            <input
              type="password"
              name="password"
              value={@form_data.password}
              phx-change="update_form"
              placeholder="Enter password..."
              class="w-full px-4 py-3 bg-gray-700 rounded-lg border border-gray-600 focus:border-green-500 focus:outline-none"
              autocomplete={if @mode == :login, do: "current-password", else: "new-password"}
              required
            />
          </div>

          <%!-- Password Confirmation (register only) --%>
          <%= if @mode == :register do %>
            <div class="mb-4">
              <label class="block text-sm font-medium mb-2">Confirm Password</label>
              <input
                type="password"
                name="password_confirmation"
                value={@form_data.password_confirmation}
                phx-change="update_form"
                placeholder="Confirm password..."
                class="w-full px-4 py-3 bg-gray-700 rounded-lg border border-gray-600 focus:border-green-500 focus:outline-none"
                autocomplete="new-password"
                required
              />
            </div>
          <% end %>

          <%!-- Submit Button --%>
          <button
            type="submit"
            class="w-full py-3 bg-green-600 hover:bg-green-500 rounded-lg font-semibold transition"
          >
            {if @mode == :login, do: "LOGIN", else: "CREATE ACCOUNT"}
          </button>
        </form>

        <%!-- Guest Mode Link --%>
        <div class="text-center mt-6">
          <.link
            navigate={~p"/snake"}
            class="text-gray-400 hover:text-green-400 text-sm"
          >
            Continue as Guest →
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_existing_atom(mode))}
  end

  def handle_event("update_form", params, socket) do
    form_data =
      socket.assigns.form_data
      |> Map.put(:name, Map.get(params, "name", socket.assigns.form_data.name))
      |> Map.put(:password, Map.get(params, "password", socket.assigns.form_data.password))
      |> Map.put(
        :password_confirmation,
        Map.get(params, "password_confirmation", socket.assigns.form_data.password_confirmation)
      )

    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("login", %{"name" => name, "password" => password}, socket) do
    case Auth.authenticate(name, password) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back, #{player.name}!")
         |> redirect(to: ~p"/snake?player_id=#{player.id}")}

      {:error, :invalid_credentials} ->
        {:noreply, assign(socket, :error, "Invalid username or password")}
    end
  end

  def handle_event(
        "register",
        %{"name" => name, "password" => password, "password_confirmation" => confirmation},
        socket
      ) do
    attrs = %{
      name: name,
      password: password,
      password_confirmation: confirmation
    }

    case Auth.register_player(attrs) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created! Welcome, #{player.name}!")
         |> redirect(to: ~p"/snake?player_id=#{player.id}")}

      {:error, changeset} ->
        error = format_changeset_errors(changeset)
        {:noreply, assign(socket, :error, error)}
    end
  end

  def handle_event("select_player", %{"id" => player_id}, socket) do
    case Auth.get_player(player_id) do
      nil ->
        {:noreply, assign(socket, :error, "Player not found")}

      player ->
        if Auth.has_password?(player) do
          # Player has password, prompt for it
          {:noreply,
           socket
           |> assign(:mode, :login)
           |> assign(:form_data, %{
             name: player.name,
             password: "",
             password_confirmation: ""
           })
           |> assign(:error, nil)}
        else
          # Guest player, redirect directly
          {:noreply,
           socket
           |> put_flash(:info, "Welcome back, #{player.name}!")
           |> redirect(to: ~p"/snake?player_id=#{player.id}")}
        end
    end
  end

  # Private helpers

  defp list_local_players do
    Auth.list_players(10)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end
end
