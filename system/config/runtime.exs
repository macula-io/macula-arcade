import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # For containerized arcade deployment, database persistence is optional
  # Default to in-memory SQLite if DATABASE_PATH not provided
  database_path = System.get_env("DATABASE_PATH") || ":memory:"

  config :macula_arcade, MaculaArcade.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # Generate a random secret key base if not provided
  # This is acceptable for stateless game servers
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      Base.encode64(:crypto.strong_rand_bytes(48))

  config :macula_arcade_web, MaculaArcadeWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    server: true,
    # Allow WebSocket connections in containerized deployment
    # For production with known domains, configure specific origins:
    # check_origin: ["//example.com", "//arcade.example.com"]
    check_origin: false

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :macula_arcade_web, MaculaArcadeWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :macula_arcade_web, MaculaArcadeWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :macula_arcade_web, MaculaArcadeWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :macula_arcade, MaculaArcade.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  config :macula_arcade, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Macula Configuration - Hybrid Mode
  # Can run as gateway (with start_gateway=true) or edge peer (start_gateway=false)
  # Set via MACULA_START_GATEWAY environment variable
  start_gateway = System.get_env("MACULA_START_GATEWAY") == "true"

  # Certificate paths for gateway mode
  # The Erlang code expects TLS_CERT_FILE and TLS_KEY_FILE environment variables
  # Set these before the Macula application starts
  cert_path = System.get_env("MACULA_CERT_PATH") || "/opt/macula/certs/cert.pem"
  key_path = System.get_env("MACULA_KEY_PATH") || "/opt/macula/certs/key.pem"

  # Realm configuration
  # The Erlang gateway code expects MACULA_REALM environment variable
  realm = System.get_env("MACULA_REALM") || "macula.arcade"

  # Set OS environment variables for the Erlang Macula code
  System.put_env("TLS_CERT_FILE", cert_path)
  System.put_env("TLS_KEY_FILE", key_path)
  System.put_env("MACULA_REALM", realm)

  config :macula,
    # Gateway mode: accepts incoming connections, provides registry
    # Edge peer mode: only makes outgoing connections
    start_gateway: start_gateway,
    # Bootstrap registry URL for initial mesh discovery
    # In production, point to a central registry node
    # For local testing with gateway mode, edge peers connect to gateway
    bootstrap_registry: System.get_env("MACULA_BOOTSTRAP_REGISTRY") || "https://localhost:4433",
    # Realm for multi-tenancy (used by Elixir SDK)
    realm: realm,
    # Gateway realm (used by Erlang gateway - fallback if GATEWAY_REALM env var not set)
    gateway_realm: realm,
    # Gateway listen port (only used if start_gateway=true)
    gateway_port: String.to_integer(System.get_env("MACULA_GATEWAY_PORT") || "4433")
end
