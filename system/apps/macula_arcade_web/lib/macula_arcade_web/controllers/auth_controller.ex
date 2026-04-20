defmodule MaculaArcadeWeb.AuthController do
  @moduledoc """
  Controller for authentication actions that require redirects.
  """

  use MaculaArcadeWeb, :controller

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/login")
  end
end
