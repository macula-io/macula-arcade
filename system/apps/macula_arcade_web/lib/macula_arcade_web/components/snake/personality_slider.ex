defmodule MaculaArcadeWeb.Components.Snake.PersonalitySlider do
  @moduledoc """
  Component for a personality trait input slider.
  Used in the snake creation form for allocating personality points.
  """

  use Phoenix.Component

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :description, :string, required: true
  attr :color, :string, required: true

  def personality_slider(assigns) do
    accent_color = accent_color(assigns.color)
    assigns = assign(assigns, :accent_color, accent_color)

    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-1">
        <span>{@label}</span>
        <span>{@value}</span>
      </div>
      <input
        type="range"
        name={@name}
        value={@value}
        min="0"
        max="100"
        class={"w-full #{@accent_color}"}
      />
      <p class="text-xs text-gray-500">{@description}</p>
    </div>
    """
  end

  defp accent_color("red"), do: "accent-red-500"
  defp accent_color("yellow"), do: "accent-yellow-500"
  defp accent_color("blue"), do: "accent-blue-500"
  defp accent_color(_), do: "accent-gray-500"
end
