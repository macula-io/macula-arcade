defmodule MaculaArcadeWeb.Components.Game.PlayerRow do
  @moduledoc """
  Component for displaying a player's score, snake info, events, and stats during gameplay.
  Used in the snake game UI to show both the current player and opponent rows.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.EventIcon

  alias MaculaArcade.SnakeMaster.Player

  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :score, :integer, required: true
  attr :asshole_factor, :integer, required: true
  attr :events, :list, required: true
  attr :is_you, :boolean, required: true
  attr :snake, :map, default: nil
  attr :player, :map, default: nil
  attr :player_name, :string, default: nil

  def player_row(assigns) do
    ~H"""
    <div class={"snake-player-panel snake-player-#{@color}"}>
      <%!-- Player Identity Row --%>
      <div class="flex items-center gap-2 mb-1">
        <%!-- Country Flag --%>
        <%= if @player && @player.country_code do %>
          <span class="text-sm" title={@player.country_code}>
            {Player.country_flag(@player.country_code)}
          </span>
        <% end %>

        <%!-- Player Handle --%>
        <%= if @player do %>
          <span class="text-xs text-gray-400 font-mono truncate max-w-[80px]" title={@player.name}>
            {@player.name}
          </span>
        <% end %>

        <%!-- YOU badge --%>
        <%= if @is_you do %>
          <span class="text-[10px] px-1 py-0.5 bg-green-900/50 text-green-400 rounded border border-green-700">
            YOU
          </span>
        <% end %>
      </div>

      <%!-- Player Label --%>
      <div class={"snake-player-label text-#{@color}-400"}>{@label}</div>

      <%!-- Snake Name or Player Name --%>
      <div class="text-sm font-mono">
        <%= if @snake do %>
          <span class={"text-#{@color}-300 font-bold"}>{@snake.name}</span>
        <% else %>
          <span class="text-gray-400">{@player_name || "Guest"}</span>
        <% end %>
      </div>

      <%!-- Score --%>
      <div class={"snake-player-score text-#{@color}-300 text-2xl font-bold"}>{@score}</div>

      <%!-- Snake TWEANN Preset (if available) --%>
      <%= if @snake && @snake.tweann_preset do %>
        <div class="flex items-center gap-1">
          <span class={"text-[10px] px-1.5 py-0.5 rounded-full " <> tweann_badge_class(@snake.tweann_preset)}>
            {preset_icon(@snake.tweann_preset)} {String.capitalize(@snake.tweann_preset)}
          </span>
        </div>
        <div class="text-[10px] text-gray-500">
          W:{@snake.wins} L:{@snake.losses}
        </div>
      <% else %>
        <%!-- Show personality for guests/bots --%>
        <div class="text-[10px] text-gray-500">
          {personality_label(@asshole_factor)}
        </div>
      <% end %>

      <%!-- Event Icon --%>
      <div class="snake-event-icon">
        <.event_icon events={@events} color={@color} />
      </div>
    </div>
    """
  end

  # TWEANN preset badge styling
  defp tweann_badge_class("hunter"), do: "bg-red-900/50 text-red-400"
  defp tweann_badge_class("survivor"), do: "bg-blue-900/50 text-blue-400"
  defp tweann_badge_class("chaotic"), do: "bg-purple-900/50 text-purple-400"
  defp tweann_badge_class("balanced"), do: "bg-green-900/50 text-green-400"
  defp tweann_badge_class(_), do: "bg-gray-700 text-gray-400"

  # TWEANN preset icons
  defp preset_icon("hunter"), do: "🎯"
  defp preset_icon("survivor"), do: "🛡️"
  defp preset_icon("chaotic"), do: "🎲"
  defp preset_icon("balanced"), do: "⚖️"
  defp preset_icon(_), do: "🔧"

  # Personality label based on asshole factor
  defp personality_label(nil), do: ""
  defp personality_label(factor) when factor < 20, do: "Gentleman"
  defp personality_label(factor) when factor < 40, do: "Chill"
  defp personality_label(factor) when factor < 60, do: "Competitive"
  defp personality_label(factor) when factor < 80, do: "Aggressive"
  defp personality_label(_factor), do: "Total Jerk"
end
