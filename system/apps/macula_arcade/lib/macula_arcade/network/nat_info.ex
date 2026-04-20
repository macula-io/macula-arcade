defmodule MaculaArcade.Network.NatInfo do
  @moduledoc """
  Module for querying NAT information from the macula mesh network.

  Provides a high-level Elixir interface to macula's NAT detection and
  connection information APIs for use in the game UI.
  """

  require Logger

  @doc """
  Gets the local NAT profile information.
  Returns a map with NAT type, public/local addresses, and capabilities.
  """
  def get_local_profile do
    try do
      case :macula_nat_detector.get_local_profile() do
        {:ok, profile} -> {:ok, normalize_profile(profile)}
        {:error, reason} -> {:error, reason}
        :not_detected -> {:ok, default_profile()}
      end
    rescue
      e ->
        Logger.warning("Failed to get NAT profile: #{inspect(e)}")
        {:ok, default_profile()}
    catch
      :exit, reason ->
        Logger.warning("NAT detector not available: #{inspect(reason)}")
        {:ok, default_profile()}
    end
  end

  @doc """
  Gets the connection mode for a specific game/peer.
  Returns :direct, :relay, :hole_punch, or :unknown.

  Note: Connection mode is determined at connection time by macula_nat_connector.
  The arcade app should track this when establishing game connections.
  This function returns :unknown as a fallback - actual mode should be
  stored in the game state when the connection is established.
  """
  def get_connection_mode(_peer_node_id) do
    # Connection mode is tracked by the application when connecting via
    # macula_nat_connector:connect/3 which returns {ok, Conn, Mode}
    # For now, return unknown - the arcade will track this in game state
    {:ok, :unknown}
  end

  @doc """
  Gets the NAT type as a human-readable string.
  """
  def nat_type_name(profile) do
    mapping = Map.get(profile, :mapping, "unknown")
    filtering = Map.get(profile, :filtering, "unknown")

    case {mapping, filtering} do
      {"EI", "EI"} -> "Full Cone"
      {"EI", "HD"} -> "Restricted Cone"
      {"EI", "PD"} -> "Port Restricted"
      {"HD", _} -> "Symmetric"
      {"PD", _} -> "Symmetric"
      _ -> "Unknown"
    end
  end

  @doc """
  Gets the NAT type code (e.g., "EI/EI/PP").
  """
  def nat_type_code(profile) do
    mapping = Map.get(profile, :mapping, "??")
    filtering = Map.get(profile, :filtering, "??")
    allocation = Map.get(profile, :allocation, "??")
    "#{mapping}/#{filtering}/#{allocation}"
  end

  @doc """
  Checks if direct P2P connections are likely to succeed.
  """
  def can_receive_direct?(profile) do
    # Full Cone and Restricted Cone can receive direct connections
    mapping = Map.get(profile, :mapping, "unknown")
    mapping == "EI"
  end

  @doc """
  Gets the public (reflexive) address if known.
  """
  def public_address(profile) do
    case Map.get(profile, :reflexive_address) do
      {ip, port} -> "#{format_ip(ip)}:#{port}"
      nil -> "unknown"
      addr -> to_string(addr)
    end
  end

  @doc """
  Gets the local address.
  """
  def local_address(profile) do
    case Map.get(profile, :local_address) do
      {ip, port} -> "#{format_ip(ip)}:#{port}"
      nil -> "unknown"
      addr -> to_string(addr)
    end
  end

  # Private functions

  defp normalize_profile(profile) when is_map(profile) do
    %{
      mapping: get_string_field(profile, :mapping),
      filtering: get_string_field(profile, :filtering),
      allocation: get_string_field(profile, :allocation),
      reflexive_address: Map.get(profile, :reflexive_address),
      local_address: Map.get(profile, :local_address),
      can_receive_unsolicited: Map.get(profile, :can_receive_unsolicited, false)
    }
  end

  defp normalize_profile(_), do: default_profile()

  defp default_profile do
    %{
      mapping: "unknown",
      filtering: "unknown",
      allocation: "unknown",
      reflexive_address: nil,
      local_address: nil,
      can_receive_unsolicited: false
    }
  end

  defp get_string_field(map, key) do
    case Map.get(map, key) do
      val when is_atom(val) -> Atom.to_string(val)
      val when is_binary(val) -> val
      _ -> "unknown"
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ip) when is_binary(ip), do: ip
  defp format_ip(ip) when is_list(ip), do: List.to_string(ip)
  defp format_ip(_), do: "unknown"
end
