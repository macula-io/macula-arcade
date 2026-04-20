defmodule MaculaArcadeWeb.Components.Snake.SnakeList do
  @moduledoc """
  Component for displaying the list of snakes in the Den.
  Shows the snake count, hatch button, and renders snake cards.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.Snake.SnakeCard

  attr :snakes, :list, required: true
  attr :max_snakes, :integer, required: true

  def snake_list(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-semibold">My Snakes ({length(@snakes)}/{@max_snakes})</h2>
        <%= if length(@snakes) < @max_snakes do %>
          <button
            phx-click="start_create_snake"
            class="px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg font-semibold transition"
          >
            + Hatch New Snake
          </button>
        <% end %>
      </div>

      <%= if Enum.empty?(@snakes) do %>
        <div class="text-center py-12 bg-gray-800 rounded-lg">
          <div class="text-6xl mb-4">🥚</div>
          <h3 class="text-xl font-semibold mb-2">No Snakes Yet</h3>
          <p class="text-gray-400 mb-4">Hatch your first snake to enter the Snake Pit!</p>
          <button
            phx-click="start_create_snake"
            class="px-6 py-3 bg-green-600 hover:bg-green-500 rounded-lg font-semibold transition"
          >
            🥚 Hatch Your First Snake
          </button>
        </div>
      <% else %>
        <div class="grid gap-4">
          <%= for snake <- @snakes do %>
            <.snake_card snake={snake} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
