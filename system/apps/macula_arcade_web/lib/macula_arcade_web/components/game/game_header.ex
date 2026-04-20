defmodule MaculaArcadeWeb.Components.Game.GameHeader do
  @moduledoc """
  Component for displaying the game header with player identification,
  game mode, status, tech info toggle, and end game buttons.
  """

  use Phoenix.Component

  attr :game_state, :map, required: true
  attr :player_id, :string, required: true
  attr :game_mode, :atom, default: :training
  attr :show_tech_panel, :boolean, default: false
  attr :player_info, :map, default: nil
  attr :snake, :map, default: nil

  def game_header(assigns) do
    ~H"""
    <div class="snake-header-row">
      <%!-- Left: Game Mode Badge --%>
      <div class="flex items-center gap-3">
        <span class={game_mode_badge_class(@game_mode)}>
          {game_mode_label(@game_mode)}
        </span>
        <span class="text-gray-500">|</span>
        <%= if @player_id == @game_state.player1_id do %>
          <span class="text-blue-400 font-bold">P1</span>
        <% else %>
          <span class="text-red-400 font-bold">P2</span>
        <% end %>
      </div>

      <%!-- Center: Game Status / Result --%>
      <%= if @game_state.game_status == :finished do %>
        <div class="flex items-center gap-3">
          <span class="text-yellow-400 font-bold">
            {game_result_message(@game_state.winner, @player_id)}
          </span>
          <button phx-click="play_again" class="arcade-btn arcade-btn-primary px-4 py-1 text-sm">
            {play_again_label(@game_mode)}
          </button>
          <button phx-click="back_to_lobby" class="arcade-btn arcade-btn-secondary px-4 py-1 text-sm">
            LOBBY
          </button>
        </div>
      <% else %>
        <div class="text-gray-500 text-sm">
          {game_status_text(@game_state)}
        </div>
      <% end %>

      <%!-- Right: Tech Info Toggle --%>
      <button
        phx-click="toggle_tech_panel"
        class={"tech-toggle-btn p-2 rounded transition " <> if(@show_tech_panel, do: "bg-gray-700 text-green-400", else: "bg-gray-800/50 text-gray-500 hover:text-gray-300")}
        title="Toggle connection info"
      >
        🔧
      </button>
    </div>
    """
  end

  # Game mode styling
  defp game_mode_badge_class(:training),
    do:
      "px-2 py-0.5 rounded text-xs font-bold bg-green-900/50 text-green-400 border border-green-700"

  defp game_mode_badge_class(:combat),
    do: "px-2 py-0.5 rounded text-xs font-bold bg-red-900/50 text-red-400 border border-red-700"

  defp game_mode_badge_class(:quick),
    do:
      "px-2 py-0.5 rounded text-xs font-bold bg-green-900/50 text-green-400 border border-green-700"

  defp game_mode_badge_class(:ranked),
    do: "px-2 py-0.5 rounded text-xs font-bold bg-red-900/50 text-red-400 border border-red-700"

  defp game_mode_badge_class(_),
    do: "px-2 py-0.5 rounded text-xs font-bold bg-gray-700 text-gray-400"

  defp game_mode_label(:training), do: "TRAINING"
  defp game_mode_label(:combat), do: "COMBAT"
  defp game_mode_label(:quick), do: "TRAINING"
  defp game_mode_label(:ranked), do: "COMBAT"
  defp game_mode_label(_), do: "GAME"

  defp play_again_label(:training), do: "TRAIN MORE"
  defp play_again_label(:combat), do: "FIGHT AGAIN"
  defp play_again_label(:quick), do: "TRAIN MORE"
  defp play_again_label(:ranked), do: "FIGHT AGAIN"
  defp play_again_label(_), do: "PLAY AGAIN"

  defp game_status_text(%{game_status: :waiting_for_ready}), do: "Waiting for players..."

  defp game_status_text(%{game_status: :countdown, countdown: countdown}) do
    Phoenix.HTML.raw(
      ~s(<span class="text-yellow-400 font-bold text-lg">#{countdown || "GO!"}</span>)
    )
  end

  defp game_status_text(_), do: "AI battle in progress"

  defp game_result_message(:draw, _player_id) do
    Phoenix.HTML.raw(~s(<span class="text-yellow-400">DRAW</span>))
  end

  defp game_result_message(winner, player_id) when winner == player_id do
    Phoenix.HTML.raw(~s(<span class="text-green-400">YOU WIN!</span>))
  end

  defp game_result_message(_winner, _player_id) do
    Phoenix.HTML.raw(~s(<span class="text-red-400">YOU LOSE</span>))
  end
end
