defmodule MaculaArcadeWeb.Components.Game.LeaderboardPanel do
  @moduledoc """
  Component for displaying the top fighters leaderboard in the arcade lobby.
  Shows snake names, wins, and losses with ranking indicators.
  """

  use Phoenix.Component

  attr :leaderboard, :list, required: true

  def leaderboard_panel(assigns) do
    ~H"""
    <div class="arcade-panel">
      <div class="arcade-panel-header">TOP FIGHTERS</div>
      <div class="p-4">
        <%= if @leaderboard == [] do %>
          <div class="text-center text-gray-500 font-mono py-8">
            NO CHAMPIONS YET<br />
            <span class="text-xs">Be the first!</span>
          </div>
        <% else %>
          <table class="w-full font-mono text-sm">
            <thead>
              <tr class="text-gray-500 text-xs">
                <th class="text-left pb-2">#</th>
                <th class="text-left pb-2">SNAKE</th>
                <th class="text-right pb-2">W</th>
                <th class="text-right pb-2">L</th>
              </tr>
            </thead>
            <tbody>
              <%= for {snake, idx} <- Enum.with_index(@leaderboard, 1) do %>
                <tr class={"leaderboard-row #{if idx == 1, do: "text-yellow-400", else: "text-gray-300"}"}>
                  <td class="py-1">
                    {rank_indicator(idx)}
                  </td>
                  <td class="py-1">
                    <div class="flex items-center gap-2">
                      <div class="w-3 h-3" style={"background-color: #{snake.head_color}"}></div>
                      <span class="truncate max-w-[120px]">{snake.name}</span>
                    </div>
                  </td>
                  <td class="text-right py-1 text-green-400">{snake.wins}</td>
                  <td class="text-right py-1 text-red-400">{snake.losses}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  defp rank_indicator(1), do: Phoenix.HTML.raw(~s(<span class="text-yellow-400">1</span>))
  defp rank_indicator(2), do: Phoenix.HTML.raw(~s(<span class="text-gray-400">2</span>))
  defp rank_indicator(3), do: Phoenix.HTML.raw(~s(<span class="text-amber-600">3</span>))
  defp rank_indicator(n), do: Phoenix.HTML.raw(~s(<span class="text-gray-500">#{n}</span>))
end
