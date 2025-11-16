defmodule MaculaArcadeWeb.PageController do
  use MaculaArcadeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
