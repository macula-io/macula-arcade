defmodule MaculaArcadeWeb.Components.Game.SnakePit do
  @moduledoc """
  The Snake Pit component - the main game arena containing:
  - Game header with player identification and status
  - Player rows showing scores and events
  - The game canvas

  This is the primary visual component during gameplay.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.Game.GameHeader
  import MaculaArcadeWeb.Components.Game.PlayerRow

  attr :game_state, :map, required: true
  attr :player_id, :string, required: true
  attr :game_mode, :atom, default: :training
  attr :show_tech_panel, :boolean, default: false
  attr :snake, :map, default: nil
  attr :player, :map, default: nil
  attr :opponent_snake, :map, default: nil
  attr :opponent_player, :map, default: nil

  def snake_pit(assigns) do
    ~H"""
    <div class="snake-game-layout">
      <%!-- Header Row: Player identification + game mode + tech toggle --%>
      <.game_header
        game_state={@game_state}
        player_id={@player_id}
        game_mode={@game_mode}
        show_tech_panel={@show_tech_panel}
      />

      <%!-- "YOU" Player Row (Top) - always show current player on top --%>
      <%= if @player_id == @game_state.player1_id do %>
        <.player_row
          label="P1"
          color="blue"
          score={@game_state.player1_score}
          asshole_factor={@game_state.player1_asshole_factor}
          events={@game_state.player1_events}
          is_you={true}
          snake={@snake}
          player={@player}
        />
      <% else %>
        <.player_row
          label="P2"
          color="red"
          score={@game_state.player2_score}
          asshole_factor={@game_state.player2_asshole_factor}
          events={@game_state.player2_events}
          is_you={true}
          snake={@snake}
          player={@player}
        />
      <% end %>

      <%!-- Arena (Middle) - scales to fill available space --%>
      <div class="snake-arena-container">
        <canvas
          id="snake-canvas"
          phx-hook="SnakeCanvas"
          data-game-state={Jason.encode!(serialize_game_state(@game_state))}
          data-player-id={@player_id}
          class="snake-canvas"
          width="800"
          height="600"
        >
        </canvas>
      </div>

      <%!-- Opponent Player Row (Bottom) --%>
      <%= if @player_id == @game_state.player1_id do %>
        <.player_row
          label="P2"
          color="red"
          score={@game_state.player2_score}
          asshole_factor={@game_state.player2_asshole_factor}
          events={@game_state.player2_events}
          is_you={false}
          snake={@opponent_snake}
          player={@opponent_player}
        />
      <% else %>
        <.player_row
          label="P1"
          color="blue"
          score={@game_state.player1_score}
          asshole_factor={@game_state.player1_asshole_factor}
          events={@game_state.player1_events}
          is_you={false}
          snake={@opponent_snake}
          player={@opponent_player}
        />
      <% end %>
    </div>
    """
  end

  # Serialize game state for the canvas hook
  defp serialize_game_state(state) do
    %{
      game_id: get_field(state, :game_id),
      player1_snake: normalize_positions(get_field(state, :player1_snake)),
      player2_snake: normalize_positions(get_field(state, :player2_snake)),
      player1_score: get_field(state, :player1_score),
      player2_score: get_field(state, :player2_score),
      food_position: normalize_position(get_field(state, :food_position)),
      game_status: get_field(state, :game_status),
      winner: get_field(state, :winner)
    }
  end

  # Get field from map with either atom or string key
  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  # Normalize position to list format [x, y]
  defp normalize_position({x, y}), do: [x, y]
  defp normalize_position([x, y]), do: [x, y]
  defp normalize_position(nil), do: [0, 0]

  # Normalize list of positions
  defp normalize_positions(nil), do: []

  defp normalize_positions(positions) when is_list(positions) do
    Enum.map(positions, &normalize_position/1)
  end
end
