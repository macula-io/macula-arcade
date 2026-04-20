defmodule MaculaArcadeWeb.Components.Game.ArcadeStatsPanel do
  @moduledoc """
  Component for displaying global arcade statistics in the lobby.
  Shows total snakes, matches played, and food consumed.
  """

  use Phoenix.Component

  attr :global_stats, :map, required: true

  def arcade_stats_panel(assigns) do
    ~H"""
    <div class="arcade-panel">
      <div class="arcade-panel-header">ARCADE STATS</div>
      <div class="p-4">
        <div class="grid grid-cols-1 gap-4 font-mono">
          <div class="stat-row">
            <span class="text-gray-400">TOTAL SNAKES</span>
            <span class="text-green-400 text-xl">{@global_stats.total_snakes || 0}</span>
          </div>
          <div class="stat-row">
            <span class="text-gray-400">MATCHES PLAYED</span>
            <span class="text-blue-400 text-xl">{@global_stats.total_matches || 0}</span>
          </div>
          <div class="stat-row">
            <span class="text-gray-400">FOOD CONSUMED</span>
            <span class="text-yellow-400 text-xl">{@global_stats.total_food || 0}</span>
          </div>
        </div>

        <%!-- Insert Coin Animation --%>
        <div class="mt-6 text-center">
          <div class="insert-coin font-mono text-sm">
            INSERT COIN
          </div>
        </div>
      </div>
    </div>
    """
  end
end
