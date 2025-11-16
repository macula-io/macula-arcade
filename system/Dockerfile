# Macula Arcade - Multi-stage Docker build
#
# This creates a single container with:
# - Phoenix web server (port 4000)
# - Macula mesh networking
# - Snake Battle Royale game

# ==============================================================================
# Build Stage
# ==============================================================================
FROM hexpm/elixir:1.17.3-erlang-27.1.2-ubuntu-jammy-20240808 AS builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git curl cmake && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config
COPY apps/macula_arcade/mix.exs apps/macula_arcade/
COPY apps/macula_arcade_web/mix.exs apps/macula_arcade_web/

# Install mix dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only $MIX_ENV

# Copy application code
COPY apps apps

# Copy TLS certificates for Macula gateway
COPY priv priv

# Compile application and build assets
RUN mix compile

# Setup and build assets using Phoenix asset pipeline
RUN mix assets.setup
RUN mix assets.deploy

# Build release
RUN mix release

# ==============================================================================
# Runtime Stage
# ==============================================================================
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create app user
RUN useradd --create-home app
WORKDIR /home/app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/macula_arcade ./

# Copy TLS certificates for Macula gateway
# Macula library expects certificates at /opt/macula/certs/
RUN mkdir -p /opt/macula/certs
COPY --from=builder --chown=app:app /app/priv/certs/server-cert.pem /opt/macula/certs/cert.pem
COPY --from=builder --chown=app:app /app/priv/certs/server-key.pem /opt/macula/certs/key.pem
RUN chmod 644 /opt/macula/certs/cert.pem && chmod 600 /opt/macula/certs/key.pem

# Switch to app user
USER app

# Expose ports
EXPOSE 4000

# Set environment
ENV MIX_ENV=prod
ENV PHX_SERVER=true

# Start the release
CMD ["bin/macula_arcade", "start"]
