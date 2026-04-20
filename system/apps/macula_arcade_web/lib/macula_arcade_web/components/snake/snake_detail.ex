defmodule MaculaArcadeWeb.Components.Snake.SnakeDetail do
  @moduledoc """
  Component for displaying the full snake detail view.
  Shows complete stats, personality bars, lifetime stats, and action buttons.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.Snake.StatusBadge
  import MaculaArcadeWeb.Components.Snake.PersonalityBar
  alias MaculaArcade.SnakeMaster.Snake

  attr :snake, :map, required: true

  def snake_detail(assigns) do
    ~H"""
    <div>
      <button
        phx-click="back_to_list"
        class="text-gray-400 hover:text-white mb-4 flex items-center gap-2"
      >
        ← Back to Den
      </button>

      <div class="bg-gray-800 rounded-lg p-6">
        <%!-- Header --%>
        <div class="flex items-center gap-4 mb-6">
          <div
            class="w-24 h-24 rounded-full flex items-center justify-center text-5xl"
            style={"background: linear-gradient(135deg, #{@snake.color_primary}, #{@snake.color_secondary})"}
          >
            🐍
          </div>
          <div>
            <h2 class="text-2xl font-bold">{@snake.name}</h2>
            <p class="text-gray-400">{Snake.personality_summary(@snake)}</p>
            <.status_badge status={@snake.status} />
          </div>
        </div>

        <%!-- Stats Grid --%>
        <div class="grid grid-cols-3 gap-4 mb-6">
          <div class="bg-gray-700 rounded-lg p-4 text-center">
            <div class="text-3xl font-bold text-green-400">{@snake.wins}</div>
            <div class="text-gray-400 text-sm">Wins</div>
          </div>
          <div class="bg-gray-700 rounded-lg p-4 text-center">
            <div class="text-3xl font-bold text-red-400">{@snake.losses}</div>
            <div class="text-gray-400 text-sm">Losses</div>
          </div>
          <div class="bg-gray-700 rounded-lg p-4 text-center">
            <div class="text-3xl font-bold text-yellow-400">
              {Float.round(Snake.win_rate(@snake), 1)}%
            </div>
            <div class="text-gray-400 text-sm">Win Rate</div>
          </div>
        </div>

        <%!-- Personality Bars --%>
        <div class="mb-6">
          <h3 class="font-semibold mb-3">Personality</h3>
          <div class="space-y-3">
            <.personality_bar label="Aggression" value={@snake.aggression} color="red" />
            <.personality_bar label="Greed" value={@snake.greed} color="yellow" />
            <.personality_bar label="Caution" value={@snake.caution} color="blue" />
          </div>
        </div>

        <%!-- Lifetime Stats --%>
        <div class="mb-6">
          <h3 class="font-semibold mb-3">Lifetime Stats</h3>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-400">Total Matches</span>
              <span>{Snake.total_matches(@snake)}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Food Eaten</span>
              <span>{@snake.total_food_eaten}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Total Kills</span>
              <span>{@snake.total_kills}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Longest Length</span>
              <span>{@snake.longest_length}</span>
            </div>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="flex gap-4">
          <%= if @snake.status == "idle" do %>
            <button
              phx-click="send_to_pit"
              phx-value-id={@snake.id}
              class="flex-1 py-3 bg-red-600 hover:bg-red-500 rounded-lg font-semibold transition"
            >
              ⚔️ Send to Snake Pit
            </button>
            <button
              phx-click="send_to_gym"
              phx-value-id={@snake.id}
              class="flex-1 py-3 bg-blue-600 hover:bg-blue-500 rounded-lg font-semibold transition opacity-50 cursor-not-allowed"
              disabled
            >
              🏋️ Send to Gym (Coming Soon)
            </button>
          <% end %>
          <button
            phx-click="delete_snake"
            phx-value-id={@snake.id}
            data-confirm="Are you sure you want to release this snake?"
            class="px-4 py-3 bg-gray-700 hover:bg-gray-600 rounded-lg transition"
          >
            🗑️
          </button>
        </div>
      </div>
    </div>
    """
  end
end
