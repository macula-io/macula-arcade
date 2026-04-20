defmodule MaculaArcadeWeb.Components.Snake.SnakeCreationForm do
  @moduledoc """
  Component for the snake creation form.
  Uses TWEANN presets for AI personality selection with optional advanced configuration.
  """

  use Phoenix.Component
  import MaculaArcadeWeb.Components.Snake.TweannPresetSelector
  import MaculaArcadeWeb.Components.Snake.TweannAdvancedPanel

  attr :form, :map, required: true

  def snake_creation_form(assigns) do
    ~H"""
    <div>
      <button
        phx-click="cancel_create"
        class="text-gray-400 hover:text-white mb-4 flex items-center gap-2"
      >
        ← Cancel
      </button>

      <div class="bg-gray-800 rounded-lg p-6">
        <h2 class="text-2xl font-bold mb-6">🥚 Hatch New Snake</h2>

        <form phx-submit="create_snake" phx-change="update_form" class="space-y-6">
          <%!-- Name --%>
          <div>
            <label class="block text-sm font-medium mb-2">Snake Name</label>
            <input
              type="text"
              name="name"
              value={@form.name}
              placeholder="Enter a name..."
              class="w-full px-4 py-2 bg-gray-700 rounded-lg border border-gray-600 focus:border-green-500 focus:outline-none"
              required
              minlength="2"
              maxlength="20"
            />
          </div>

          <%!-- TWEANN Preset Selector --%>
          <.tweann_preset_selector
            selected={@form.tweann_preset}
            show_custom={@form.show_advanced_tweann}
          />

          <%!-- Advanced TWEANN Settings --%>
          <.tweann_advanced_panel form={@form} visible={@form.show_advanced_tweann} />

          <%!-- Colors --%>
          <div>
            <h3 class="font-semibold mb-4">Colors</h3>
            <div class="flex gap-4">
              <div class="flex-1">
                <label class="block text-sm mb-2">Primary</label>
                <input
                  type="color"
                  name="color_primary"
                  value={@form.color_primary}
                  class="w-full h-10 rounded cursor-pointer"
                />
              </div>
              <div class="flex-1">
                <label class="block text-sm mb-2">Secondary</label>
                <input
                  type="color"
                  name="color_secondary"
                  value={@form.color_secondary}
                  class="w-full h-10 rounded cursor-pointer"
                />
              </div>
              <div class="flex-1">
                <label class="block text-sm mb-2">Preview</label>
                <div
                  class="w-full h-10 rounded flex items-center justify-center text-xl"
                  style={"background: linear-gradient(135deg, #{@form.color_primary}, #{@form.color_secondary})"}
                >
                  🐍
                </div>
              </div>
            </div>
          </div>

          <%!-- Submit --%>
          <button
            type="submit"
            disabled={String.length(@form.name || "") < 2}
            class={"w-full py-3 rounded-lg font-semibold transition " <>
              if(String.length(@form.name || "") >= 2,
                do: "bg-green-600 hover:bg-green-500",
                else: "bg-gray-600 cursor-not-allowed")}
          >
            🐍 Hatch Snake
          </button>
        </form>
      </div>
    </div>
    """
  end
end
