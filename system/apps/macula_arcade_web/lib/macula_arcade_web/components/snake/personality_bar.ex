defmodule MaculaArcadeWeb.Components.Snake.PersonalityBar do
  @moduledoc """
  Component for displaying a personality trait as a progress bar.
  Used in snake detail views to show aggression, greed, and caution levels.
  """

  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, required: true

  def personality_bar(assigns) do
    bar_color = bar_color(assigns.color)
    assigns = assign(assigns, :bar_color, bar_color)

    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-1">
        <span>{@label}</span>
        <span>{@value}/100</span>
      </div>
      <div class="h-2 bg-gray-700 rounded-full overflow-hidden">
        <div class={"h-full #{@bar_color} rounded-full transition-all"} style={"width: #{@value}%"}>
        </div>
      </div>
    </div>
    """
  end

  defp bar_color("red"), do: "bg-red-500"
  defp bar_color("yellow"), do: "bg-yellow-500"
  defp bar_color("blue"), do: "bg-blue-500"
  defp bar_color(_), do: "bg-gray-500"
end
