defmodule MaculaArcadeWeb.Components.Snake.TweannAdvancedPanel do
  @moduledoc """
  Advanced TWEANN configuration panel.
  Shows detailed sliders for mutation rate, memory depth, risk tolerance, and exploration rate.
  """

  use Phoenix.Component

  attr :form, :map, required: true
  attr :visible, :boolean, default: false

  def tweann_advanced_panel(assigns) do
    ~H"""
    <div class="space-y-4">
      <button
        type="button"
        phx-click="toggle_advanced"
        class="flex items-center gap-2 text-sm text-gray-400 hover:text-white transition"
      >
        <%= if @visible do %>
          <span>▼</span>
          <span>Hide Advanced Settings</span>
        <% else %>
          <span>▶</span>
          <span>Show Advanced Settings</span>
        <% end %>
      </button>

      <%= if @visible do %>
        <div class="bg-gray-700/50 rounded-lg p-4 space-y-4 border border-gray-600">
          <p class="text-xs text-gray-400 mb-4">
            Fine-tune your snake's neural evolution parameters. Using custom settings will set preset to "custom".
          </p>

          <.tweann_slider
            name="tweann_mutation_rate"
            label="Mutation Rate"
            value={@form.tweann_mutation_rate}
            min={0.01}
            max={0.5}
            step={0.01}
            description="How fast the brain evolves (higher = more volatile)"
            format={:percent}
          />

          <.tweann_slider
            name="tweann_memory_depth"
            label="Memory Depth"
            value={@form.tweann_memory_depth}
            min={1}
            max={10}
            step={1}
            description="Game ticks remembered (higher = smarter but slower)"
            format={:integer}
          />

          <.tweann_slider
            name="tweann_risk_tolerance"
            label="Risk Tolerance"
            value={@form.tweann_risk_tolerance}
            min={0}
            max={100}
            step={5}
            description="Willingness to take dangerous moves (higher = braver)"
            format={:integer}
          />

          <.tweann_slider
            name="tweann_exploration_rate"
            label="Exploration Rate"
            value={@form.tweann_exploration_rate}
            min={0}
            max={100}
            step={5}
            description="Try new strategies vs exploit known (higher = more experimental)"
            format={:integer}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :min, :any, required: true
  attr :max, :any, required: true
  attr :step, :any, required: true
  attr :description, :string, required: true
  attr :format, :atom, default: :float

  defp tweann_slider(assigns) do
    display_value =
      case assigns.format do
        :percent -> "#{round(assigns.value * 100)}%"
        :integer -> "#{round(assigns.value)}"
        _ -> "#{assigns.value}"
      end

    assigns = assign(assigns, :display_value, display_value)

    ~H"""
    <div>
      <div class="flex justify-between items-center mb-1">
        <label class="text-sm font-medium">{@label}</label>
        <span class="text-sm text-cyan-400 font-mono">{@display_value}</span>
      </div>
      <input
        type="range"
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        class="w-full h-2 bg-gray-600 rounded-lg appearance-none cursor-pointer slider-cyan"
      />
      <p class="text-xs text-gray-500 mt-1">{@description}</p>
    </div>
    """
  end
end
