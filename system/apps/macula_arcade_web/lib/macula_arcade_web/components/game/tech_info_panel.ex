defmodule MaculaArcadeWeb.Components.Game.TechInfoPanel do
  @moduledoc """
  Collapsible overlay panel showing NAT/connection technical information.

  Displays:
  - Connection mode (Direct P2P / Via Relay)
  - Latency in milliseconds
  - NAT type with human-readable name
  - Public and local addresses
  - Hole punch status
  - Game tick and FPS

  Toggleable via a gear button in the top-right corner during gameplay.
  """

  use Phoenix.Component
  alias MaculaArcade.Network.NatInfo

  attr :show, :boolean, default: false
  attr :nat_info, :map, default: nil
  attr :connection_mode, :atom, default: :unknown
  attr :latency_ms, :integer, default: nil
  attr :opponent_nat_type, :string, default: nil
  attr :hole_punch_result, :atom, default: nil
  attr :game_tick, :integer, default: 0

  def tech_info_panel(assigns) do
    ~H"""
    <div class="tech-panel-container fixed top-2 right-2 z-40">
      <%!-- Toggle Button - always visible --%>
      <button
        phx-click="toggle_tech_panel"
        class="tech-panel-toggle bg-gray-800/80 hover:bg-gray-700/80 p-2 rounded-lg border border-gray-600 transition"
        title="Toggle connection info"
      >
        <span class="text-gray-400 text-lg">🔧</span>
      </button>

      <%!-- Panel Content - shown when expanded --%>
      <%= if @show do %>
        <div class="tech-panel bg-gray-900/95 rounded-lg border border-gray-600 mt-2 p-4 min-w-[280px] shadow-xl">
          <div class="flex justify-between items-center mb-3 border-b border-gray-700 pb-2">
            <span class="text-gray-300 font-mono text-sm flex items-center gap-2">
              <span>🌐</span> Connection Info
            </span>
            <button phx-click="toggle_tech_panel" class="text-gray-500 hover:text-gray-300">
              ×
            </button>
          </div>

          <div class="space-y-3 font-mono text-xs">
            <%!-- Connection Mode --%>
            <div class="flex justify-between items-center">
              <span class="text-gray-400">Mode:</span>
              <span class={connection_mode_class(@connection_mode)}>
                {connection_mode_text(@connection_mode)}
              </span>
            </div>

            <%!-- Latency --%>
            <div class="flex justify-between items-center">
              <span class="text-gray-400">Latency:</span>
              <span class={latency_class(@latency_ms)}>
                {format_latency(@latency_ms)}
              </span>
            </div>

            <div class="border-t border-gray-700 pt-2 mt-2">
              <div class="text-gray-500 text-[10px] mb-2">YOUR NAT</div>

              <%!-- NAT Type --%>
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Type:</span>
                <span class="text-gray-200">
                  {nat_type_code(@nat_info)}
                  <span class="text-gray-500">({nat_type_name(@nat_info)})</span>
                </span>
              </div>

              <%!-- Public Address --%>
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Public:</span>
                <span class="text-cyan-400">{public_address(@nat_info)}</span>
              </div>

              <%!-- Local Address --%>
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Local:</span>
                <span class="text-gray-300">{local_address(@nat_info)}</span>
              </div>

              <%!-- Can Receive Direct --%>
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Direct OK:</span>
                <span class={
                  if can_receive_direct?(@nat_info), do: "text-green-400", else: "text-red-400"
                }>
                  {if can_receive_direct?(@nat_info), do: "✓", else: "✗"}
                </span>
              </div>
            </div>

            <%!-- Opponent Info (if available) --%>
            <%= if @opponent_nat_type do %>
              <div class="border-t border-gray-700 pt-2 mt-2">
                <div class="text-gray-500 text-[10px] mb-2">OPPONENT NAT</div>
                <div class="flex justify-between items-center">
                  <span class="text-gray-400">Type:</span>
                  <span class="text-gray-200">{@opponent_nat_type}</span>
                </div>
              </div>
            <% end %>

            <%!-- Hole Punch Status --%>
            <%= if @hole_punch_result do %>
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Hole Punch:</span>
                <span class={hole_punch_class(@hole_punch_result)}>
                  {hole_punch_text(@hole_punch_result)}
                </span>
              </div>
            <% end %>

            <%!-- Game Stats --%>
            <div class="border-t border-gray-700 pt-2 mt-2 flex justify-between items-center">
              <span class="text-gray-500">Tick: {@game_tick}</span>
              <span class="text-gray-500">FPS: 10</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Connection mode helpers
  defp connection_mode_text(:direct), do: "Direct P2P ✓"
  defp connection_mode_text(:relay), do: "Via Relay 🔄"
  defp connection_mode_text(_), do: "Unknown"

  defp connection_mode_class(:direct), do: "text-green-400"
  defp connection_mode_class(:relay), do: "text-yellow-400"
  defp connection_mode_class(_), do: "text-gray-400"

  # Latency helpers
  defp format_latency(nil), do: "—"
  defp format_latency(ms), do: "#{ms}ms"

  defp latency_class(nil), do: "text-gray-400"
  defp latency_class(ms) when ms < 50, do: "text-green-400"
  defp latency_class(ms) when ms < 100, do: "text-yellow-400"
  defp latency_class(_), do: "text-red-400"

  # NAT info helpers (delegate to NatInfo module)
  defp nat_type_code(nil), do: "??/??/??"
  defp nat_type_code(profile), do: NatInfo.nat_type_code(profile)

  defp nat_type_name(nil), do: "Unknown"
  defp nat_type_name(profile), do: NatInfo.nat_type_name(profile)

  defp public_address(nil), do: "unknown"
  defp public_address(profile), do: NatInfo.public_address(profile)

  defp local_address(nil), do: "unknown"
  defp local_address(profile), do: NatInfo.local_address(profile)

  defp can_receive_direct?(nil), do: false
  defp can_receive_direct?(profile), do: NatInfo.can_receive_direct?(profile)

  # Hole punch status helpers
  defp hole_punch_text(:success), do: "Success"
  defp hole_punch_text(:failed), do: "Failed"
  defp hole_punch_text(:pending), do: "Pending..."
  defp hole_punch_text(_), do: "—"

  defp hole_punch_class(:success), do: "text-green-400"
  defp hole_punch_class(:failed), do: "text-red-400"
  defp hole_punch_class(:pending), do: "text-yellow-400"
  defp hole_punch_class(_), do: "text-gray-400"
end
