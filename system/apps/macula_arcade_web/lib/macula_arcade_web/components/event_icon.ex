defmodule MaculaArcadeWeb.Components.EventIcon do
  @moduledoc """
  Component for displaying the last game event as a large animated icon.

  Replaces the scrolling event list with a single expressive icon that
  shows the most recent action (turn direction, food eaten, collision, win/lose).
  """

  use Phoenix.Component

  @doc """
  Renders the last event as a large icon with animation.

  ## Examples

      <.event_icon events={@game_state.player1_events} color="blue" />
      <.event_icon events={@game_state.player2_events} color="red" />
  """
  attr :events, :list, required: true
  attr :color, :string, default: "blue"

  def event_icon(assigns) do
    {icon, animation} = get_last_event_icon(assigns.events)
    # Generate a unique key from the event to prevent animation restart on unrelated re-renders
    event_key = event_key(assigns.events)
    assigns = assign(assigns, :icon, icon)
    assigns = assign(assigns, :animation, animation)
    assigns = assign(assigns, :event_key, event_key)

    ~H"""
    <div class={"flex items-center justify-center h-full event-icon-container text-#{@color}-400"}>
      <span id={@event_key} class={"text-6xl event-icon #{@animation}"}>{@icon}</span>
    </div>
    """
  end

  # Generate a unique key from the first event to prevent unnecessary re-renders
  defp event_key([]), do: "event-none"

  defp event_key([event | _]) do
    type = get_field(event, :type) || "unknown"
    value = get_field(event, :value) || "unknown"
    # Include a timestamp or counter if available to make each event unique
    ts =
      get_field(event, :timestamp) || get_field(event, :ts) || System.unique_integer([:positive])

    "event-#{type}-#{value}-#{ts}"
  end

  defp get_field(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  @doc """
  Converts an event to its icon representation and animation class.
  Returns {icon, animation_class} tuple.
  """
  def event_to_icon(%{"type" => "turn", "value" => "up"}), do: {"↑", "animate-pulse-fast"}
  def event_to_icon(%{"type" => "turn", "value" => "down"}), do: {"↓", "animate-pulse-fast"}
  def event_to_icon(%{"type" => "turn", "value" => "left"}), do: {"←", "animate-pulse-fast"}
  def event_to_icon(%{"type" => "turn", "value" => "right"}), do: {"→", "animate-pulse-fast"}
  def event_to_icon(%{"type" => "food", "value" => _}), do: {"🍎", "animate-bounce-scale"}
  def event_to_icon(%{"type" => "collision", "value" => "wall"}), do: {"🧱", "animate-shake"}
  def event_to_icon(%{"type" => "collision", "value" => "self"}), do: {"🔄", "animate-spin-once"}
  def event_to_icon(%{"type" => "collision", "value" => "snake"}), do: {"💥", "animate-explode"}

  def event_to_icon(%{"type" => "collision", "value" => "head_to_head"}),
    do: {"💥", "animate-explode"}

  def event_to_icon(%{"type" => "win", "value" => _}), do: {"🎉", "animate-confetti"}
  # Atom key variants (from local state)
  def event_to_icon(%{type: "turn", value: "up"}), do: {"↑", "animate-pulse-fast"}
  def event_to_icon(%{type: "turn", value: "down"}), do: {"↓", "animate-pulse-fast"}
  def event_to_icon(%{type: "turn", value: "left"}), do: {"←", "animate-pulse-fast"}
  def event_to_icon(%{type: "turn", value: "right"}), do: {"→", "animate-pulse-fast"}
  def event_to_icon(%{type: "food", value: _}), do: {"🍎", "animate-bounce-scale"}
  def event_to_icon(%{type: "collision", value: "wall"}), do: {"🧱", "animate-shake"}
  def event_to_icon(%{type: "collision", value: "self"}), do: {"🔄", "animate-spin-once"}
  def event_to_icon(%{type: "collision", value: "snake"}), do: {"💥", "animate-explode"}
  def event_to_icon(%{type: "collision", value: "head_to_head"}), do: {"💥", "animate-explode"}
  def event_to_icon(%{type: "win", value: _}), do: {"🎉", "animate-confetti"}
  def event_to_icon(_), do: {"•", ""}

  # Get the last event and convert to icon
  defp get_last_event_icon([]), do: {"•", ""}
  defp get_last_event_icon([last_event | _]), do: event_to_icon(last_event)
end
