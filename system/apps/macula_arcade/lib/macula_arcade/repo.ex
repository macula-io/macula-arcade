defmodule MaculaArcade.Repo do
  use Ecto.Repo,
    otp_app: :macula_arcade,
    adapter: Ecto.Adapters.SQLite3
end
