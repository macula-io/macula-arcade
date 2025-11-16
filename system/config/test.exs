import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :macula_arcade, MaculaArcade.Repo,
  database: Path.expand("../macula_arcade_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :macula_arcade_web, MaculaArcadeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "j0BS1HO0JSw7jC2LnonXa1DMtHX0gEm/pLd0oq3ROlhNgFrKUB5Z/vsjuf/XLWMO",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Disable Macula gateway mode in tests (no TLS certs required)
config :macula,
  start_gateway: false,
  realm: "test.realm",
  bootstrap_registry: "https://localhost:4433"

# In test we don't send emails
config :macula_arcade, MaculaArcade.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
