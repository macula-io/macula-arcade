defmodule MaculaArcadeWeb.HomeLive do
  use MaculaArcadeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Macula Arcade - Decentralized Gaming")
      |> assign(:selected_game, nil)
      |> assign(:games, list_games())

    {:ok, socket}
  end

  @impl true
  def handle_event("select_game", %{"game" => game_id}, socket) do
    {:noreply, assign(socket, :selected_game, game_id)}
  end

  @impl true
  def handle_event("launch_game", %{"game" => "snake_battle_royale"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/snake")}
  end

  @impl true
  def handle_event("launch_game", _params, socket) do
    # Game not yet implemented
    {:noreply, socket}
  end

  defp list_games do
    [
      %{
        id: "snake_battle_royale",
        name: "Snake Battle Royale",
        status: :available,
        description: "Classic snake gameplay meets battle royale. Last snake standing wins!",
        players: "1-100",
        ascii_art: """
        ╔═══╗ ╔═╗  ╔═╗ ╔═══╗ ╦  ╦ ╔═══╗
        ║ ╔═╝ ║ ║  ║ ║ ║ ╔═╝ ║ ╔╝ ║ ╔═╝
        ║ ╚═╗ ║ ╚══╝ ║ ║ ╚═╗ ║ ╚╗ ║ ╚═╗
        ╚═══╝ ╚══════╝ ╚═══╝ ╩  ╩ ╚═══╝
        """
      },
      %{
        id: "pong_multiplayer",
        name: "Mesh Pong",
        status: :coming_soon,
        description: "Peer-to-peer pong. No servers, no tracking, just pure gameplay.",
        players: "2",
        ascii_art: """
        ╔═══╗  ╔═══╗  ╔═╗  ╦  ╔═══╗
        ║ ╔═╝  ║ ╔═╝  ║ ║  ║  ║ ╔═╝
        ║ ╚═╗  ║ ║    ║ ╚══╝  ║ ║
        ╚═══╝  ╚═╝    ╚══════╝ ╚═╝
        """
      },
      %{
        id: "tetris_cooperative",
        name: "Co-op Tetris",
        status: :coming_soon,
        description: "Collaborative block-stacking. Build together across the mesh.",
        players: "2-4",
        ascii_art: """
        ╔═══════╗ ╔═══════╗ ╔═══════╗
        ║ ▀▀▀▀▀ ║ ║ ▀▀▀▀▀ ║ ║ ▀▀▀▀▀ ║
        ║ █ █ █ ║ ║ █ █ █ ║ ║ █ █ █ ║
        ╚═══════╝ ╚═══════╝ ╚═══════╝
        """
      },
      %{
        id: "asteroids_swarm",
        name: "Asteroid Swarm",
        status: :coming_soon,
        description: "Defend the mesh. Decentralized space combat.",
        players: "1-50",
        ascii_art: """
         *  .  *    .   *  .
        .  *   . * .  *  . *
          *  . *  .  * .  *
        """
      }
    ]
  end
end
