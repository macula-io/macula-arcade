defmodule MaculaArcadeWeb.Components.Snake.StatusBadge do
  @moduledoc """
  Component for displaying a snake's status as a small badge.
  Supports idle, in_pit, and training statuses with appropriate colors.
  """

  use Phoenix.Component

  attr :status, :string, required: true

  def status_badge(assigns) do
    color = status_color(assigns.status)
    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"px-2 py-0.5 text-xs rounded #{@color}"}>
      {String.upcase(@status)}
    </span>
    """
  end

  defp status_color("idle"), do: "bg-gray-600"
  defp status_color("in_pit"), do: "bg-red-600"
  defp status_color("in_queue"), do: "bg-yellow-600"
  defp status_color("training"), do: "bg-blue-600"
  defp status_color(_), do: "bg-gray-600"
end
