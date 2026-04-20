defmodule MaculaArcadeWeb.Components.Game.SelectedSnakeCard do
  @moduledoc """
  Component for displaying the currently selected snake/fighter in the lobby.
  Shows when a player has chosen a snake from the Den to battle with.
  """

  use Phoenix.Component

  attr :snake, :map, required: true
  attr :player, :map, required: true

  def selected_snake_card(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mb-8 arcade-panel">
      <div class="arcade-panel-header">SELECTED FIGHTER</div>
      <div class="p-4">
        <div class="flex items-center gap-4 mb-4">
          <div
            class="w-16 h-16 rounded flex items-center justify-center pixel-border"
            style={"background-color: #{@snake.body_color}"}
          >
            <div class="w-8 h-8 rounded" style={"background-color: #{@snake.head_color}"}></div>
          </div>
          <div class="text-left">
            <div class="text-xl font-bold text-green-400 font-mono">{@snake.name}</div>
            <div class="text-gray-400 text-sm font-mono">by {@player.name}</div>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2 text-center font-mono">
          <div class="stat-box">
            <div class="text-red-400 text-lg">{@snake.aggression}</div>
            <div class="text-xs text-gray-500">AGG</div>
          </div>
          <div class="stat-box">
            <div class="text-yellow-400 text-lg">{@snake.greed}</div>
            <div class="text-xs text-gray-500">GRD</div>
          </div>
          <div class="stat-box">
            <div class="text-blue-400 text-lg">{@snake.caution}</div>
            <div class="text-xs text-gray-500">CTN</div>
          </div>
        </div>
        <div class="mt-3 text-center font-mono text-sm">
          <span class="text-green-400">{@snake.wins}W</span>
          <span class="text-gray-500 mx-2">/</span>
          <span class="text-red-400">{@snake.losses}L</span>
        </div>
      </div>
    </div>
    """
  end
end
