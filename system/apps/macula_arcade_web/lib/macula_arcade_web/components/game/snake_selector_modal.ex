defmodule MaculaArcadeWeb.Components.Game.SnakeSelectorModal do
  @moduledoc """
  Modal component for selecting a snake from the player's collection.
  Used in the lobby to switch snakes before starting a game.
  """

  use Phoenix.Component
  alias MaculaArcade.SnakeMaster.Snake

  attr :show, :boolean, default: false
  attr :snakes, :list, default: []
  attr :selected_snake_id, :string, default: nil

  def snake_selector_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
        phx-click="close_snake_selector"
      >
        <div
          class="bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4 border border-gray-700"
          phx-click-away="close_snake_selector"
        >
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold text-green-400">Select Your Snake</h2>
            <button
              phx-click="close_snake_selector"
              class="text-gray-400 hover:text-white text-2xl"
            >
              &times;
            </button>
          </div>

          <%= if @snakes == [] do %>
            <div class="text-center py-8">
              <p class="text-gray-400 mb-4">You don't have any snakes yet!</p>
              <.link
                navigate="/den"
                class="inline-block px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg"
              >
                Create Your First Snake
              </.link>
            </div>
          <% else %>
            <div class="space-y-3 max-h-96 overflow-y-auto">
              <%= for snake <- @snakes do %>
                <.snake_option
                  snake={snake}
                  selected={snake.id == @selected_snake_id}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  attr :snake, :map, required: true
  attr :selected, :boolean, default: false

  defp snake_option(assigns) do
    border_class =
      if assigns.selected do
        "border-green-500 bg-green-900/30"
      else
        "border-gray-700 hover:border-gray-600"
      end

    assigns = assign(assigns, :border_class, border_class)

    ~H"""
    <button
      type="button"
      phx-click="select_snake_from_modal"
      phx-value-snake_id={@snake.id}
      class={"w-full p-4 rounded-lg border-2 text-left transition cursor-pointer " <> @border_class}
    >
      <div class="flex items-center gap-4">
        <%!-- Snake color preview --%>
        <div
          class="w-12 h-12 rounded-lg flex items-center justify-center text-2xl"
          style={"background: linear-gradient(135deg, #{@snake.color_primary}, #{@snake.color_secondary})"}
        >
          🐍
        </div>

        <div class="flex-1">
          <div class="flex items-center gap-2">
            <span class="font-semibold">{@snake.name}</span>
            <%= if @selected do %>
              <span class="text-green-400">✓</span>
            <% end %>
          </div>

          <%!-- TWEANN preset badge --%>
          <div class="flex items-center gap-2 mt-1">
            <span class={"text-xs px-2 py-0.5 rounded-full " <> preset_badge_class(@snake.tweann_preset)}>
              {String.capitalize(@snake.tweann_preset || "balanced")}
            </span>
            <span class="text-xs text-gray-500">
              {Snake.win_rate(@snake)}% WR
            </span>
          </div>

          <%!-- Stats line --%>
          <div class="text-xs text-gray-400 mt-1">
            {Snake.total_matches(@snake)} matches • {Snake.personality_summary(@snake)}
          </div>
        </div>
      </div>
    </button>
    """
  end

  defp preset_badge_class("hunter"), do: "bg-red-900/50 text-red-400"
  defp preset_badge_class("survivor"), do: "bg-blue-900/50 text-blue-400"
  defp preset_badge_class("chaotic"), do: "bg-purple-900/50 text-purple-400"
  defp preset_badge_class("balanced"), do: "bg-green-900/50 text-green-400"
  defp preset_badge_class("custom"), do: "bg-gray-700 text-gray-400"
  defp preset_badge_class(_), do: "bg-gray-700 text-gray-400"
end
