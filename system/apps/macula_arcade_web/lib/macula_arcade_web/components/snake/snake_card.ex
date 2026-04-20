defmodule MaculaArcadeWeb.Components.Snake.SnakeCard do
  @moduledoc """
  Component for displaying a snake as a list item card.
  Shows avatar, name, status, stats (W/L/D), and action buttons.
  Used in both the Den snake list and potentially other views.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.Snake.StatusBadge
  alias MaculaArcade.SnakeMaster.Snake

  attr :snake, :map, required: true

  def snake_card(assigns) do
    ~H"""
    <div
      class="bg-gray-800 rounded-lg p-4 flex items-center gap-4 hover:bg-gray-750 transition cursor-pointer"
      phx-click="select_snake"
      phx-value-id={@snake.id}
    >
      <%!-- Snake Avatar --%>
      <div
        class="w-16 h-16 rounded-full flex items-center justify-center text-3xl"
        style={"background: linear-gradient(135deg, #{@snake.color_primary}, #{@snake.color_secondary})"}
      >
        🐍
      </div>

      <%!-- Snake Info --%>
      <div class="flex-1">
        <div class="flex items-center gap-2">
          <h3 class="font-bold text-lg">{@snake.name}</h3>
          <.status_badge status={@snake.status} />
        </div>
        <p class="text-gray-400 text-sm">{Snake.personality_summary(@snake)}</p>
        <div class="flex gap-4 mt-1 text-sm">
          <span class="text-green-400">{@snake.wins}W</span>
          <span class="text-red-400">{@snake.losses}L</span>
          <span class="text-gray-400">{@snake.draws}D</span>
          <span class="text-yellow-400">{Float.round(Snake.win_rate(@snake), 1)}%</span>
        </div>
      </div>

      <%!-- Actions --%>
      <div class="flex gap-2">
        <%= if @snake.status == "idle" do %>
          <button
            phx-click="send_to_pit"
            phx-value-id={@snake.id}
            class="px-3 py-2 bg-red-600 hover:bg-red-500 rounded text-sm font-semibold transition"
          >
            ⚔️ Pit
          </button>
          <button
            phx-click="send_to_gym"
            phx-value-id={@snake.id}
            class="px-3 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-semibold transition"
            disabled
            title="Coming soon!"
          >
            🏋️ Gym
          </button>
        <% else %>
          <span class="px-3 py-2 bg-gray-700 rounded text-sm text-gray-400">
            {status_text(@snake.status)}
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_text("idle"), do: "Resting"
  defp status_text("in_pit"), do: "In Battle"
  defp status_text("in_queue"), do: "In Queue"
  defp status_text("training"), do: "Training"
  defp status_text(_), do: "Unknown"
end
