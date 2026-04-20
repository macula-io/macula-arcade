defmodule MaculaArcadeWeb.Components.Snake.TweannPresetSelector do
  @moduledoc """
  Component for selecting TWEANN presets.
  Displays preset cards with descriptions and allows selection.
  """

  use Phoenix.Component

  alias MaculaArcade.SnakeMaster.Snake

  attr :selected, :string, default: "balanced"
  attr :show_custom, :boolean, default: false

  def tweann_preset_selector(assigns) do
    presets =
      if assigns.show_custom,
        do: Snake.tweann_presets(),
        else: Enum.reject(Snake.tweann_presets(), &(&1 == "custom"))

    assigns = assign(assigns, :presets, presets)

    ~H"""
    <div class="space-y-4">
      <h3 class="font-semibold">AI Personality</h3>
      <p class="text-sm text-gray-400 mb-4">
        Choose how your snake's brain will evolve during battles
      </p>

      <div class="grid grid-cols-2 gap-3">
        <%= for preset <- @presets do %>
          <.preset_card
            preset={preset}
            selected={@selected == preset}
            config={Snake.preset_config(preset)}
            icon={preset_icon(preset)}
            color={preset_color(preset)}
          />
        <% end %>
      </div>
    </div>
    """
  end

  defp preset_icon("hunter"), do: "🎯"
  defp preset_icon("survivor"), do: "🛡️"
  defp preset_icon("chaotic"), do: "🎲"
  defp preset_icon("balanced"), do: "⚖️"
  defp preset_icon("custom"), do: "🔧"
  defp preset_icon(_), do: "❓"

  defp preset_color("hunter"), do: "red"
  defp preset_color("survivor"), do: "blue"
  defp preset_color("chaotic"), do: "purple"
  defp preset_color("balanced"), do: "green"
  defp preset_color(_), do: "gray"

  attr :preset, :string, required: true
  attr :selected, :boolean, required: true
  attr :config, :map, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp preset_card(assigns) do
    border_class =
      case {assigns.selected, assigns.color} do
        {true, "red"} -> "border-red-500 bg-red-900/30"
        {true, "blue"} -> "border-blue-500 bg-blue-900/30"
        {true, "purple"} -> "border-purple-500 bg-purple-900/30"
        {true, "green"} -> "border-green-500 bg-green-900/30"
        {true, _} -> "border-gray-500 bg-gray-700"
        _ -> "border-gray-700 hover:border-gray-600"
      end

    text_class =
      case assigns.color do
        "red" -> "text-red-400"
        "blue" -> "text-blue-400"
        "purple" -> "text-purple-400"
        "green" -> "text-green-400"
        _ -> "text-gray-400"
      end

    assigns =
      assigns
      |> assign(:border_class, border_class)
      |> assign(:text_class, text_class)

    ~H"""
    <button
      type="button"
      phx-click="select_preset"
      phx-value-preset={@preset}
      class={"p-4 rounded-lg border-2 text-left transition cursor-pointer " <> @border_class}
    >
      <div class="flex items-center gap-2 mb-2">
        <span class="text-2xl">{@icon}</span>
        <span class={"font-semibold capitalize " <> @text_class}>{@preset}</span>
        <%= if @selected do %>
          <span class="ml-auto text-green-400">✓</span>
        <% end %>
      </div>
      <p class="text-sm text-gray-400">{@config.description}</p>
    </button>
    """
  end
end
