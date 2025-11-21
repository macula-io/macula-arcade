# Macula Arcade - Development Environment

**Purpose:** Separate development instance for active coding while keeping stable demo running.

---

## Overview

This development setup provides:

- **Separate Ports:** Dev runs on 5000-5003, Demo runs on 4000-4003
- **Separate Network:** Dev uses 172.26.0.0/24, Demo uses 172.25.0.0/24
- **Local Source:** Builds from `./system/` directory (your working code)
- **Debug Logging:** LOG_LEVEL=debug for detailed output
- **Hot Rebuilds:** Quick rebuild cycle for development

---

## Port Layout

| Environment | HTTP Ports | QUIC Ports | Health Ports |
|-------------|------------|------------|--------------|
| **DEMO (stable)** | 4000-4003 | 4433-4436 | 8080-8083 |
| **DEV (active)** | 5000-5003 | 5433-5436 | 9080-9083 |

**Both can run simultaneously without conflicts!**

---

## Quick Start

### 1. Deploy Development Environment

```bash
cd /home/rl/work/github.com/macula-io/macula-arcade
./deploy-dev.sh
```

**What it does:**
1. Stops existing dev containers
2. Builds from local `./system/` code
3. Starts dev containers on ports 5000+
4. Waits for health checks
5. Shows access URLs

**Time:** ~2-3 minutes first build, ~30-60 seconds with cache

### 2. Access Development Instance

Open browser to:
- Gateway: http://localhost:5000
- Peer 1: http://localhost:5001
- Peer 2: http://localhost:5002

### 3. Make Code Changes

Edit files in `./system/apps/...`

### 4. Rebuild and Test

```bash
docker compose -f docker-compose.dev.yml up --build -d
```

Or use the script again:
```bash
./deploy-dev.sh
```

---

## Development Workflow

### Typical Development Cycle

```bash
# 1. Start dev environment
./deploy-dev.sh

# 2. Edit code
vim system/apps/macula_arcade/lib/macula_arcade/games/snake/game_server.ex

# 3. Rebuild with changes
docker compose -f docker-compose.dev.yml up --build -d

# 4. Test at http://localhost:5000

# 5. Check logs for errors
docker compose -f docker-compose.dev.yml logs -f dev-gateway

# 6. Repeat steps 2-5
```

### Quick Commands

```bash
# View logs (all services)
docker compose -f docker-compose.dev.yml logs -f

# View logs (specific service)
docker compose -f docker-compose.dev.yml logs -f dev-gateway
docker compose -f docker-compose.dev.yml logs -f dev-peer1

# Restart a single service
docker compose -f docker-compose.dev.yml restart dev-gateway

# Stop dev environment (keeps demo running)
docker compose -f docker-compose.dev.yml down

# Full cleanup (remove volumes too)
docker compose -f docker-compose.dev.yml down -v
```

---

## Development vs Demo

### When to Use Development

Use DEV for:
- ✅ Testing new features
- ✅ Debugging issues
- ✅ Breaking changes
- ✅ Experimental code
- ✅ TWEANN integration work
- ✅ Database schema changes

### When to Use Demo

Use DEMO for:
- ✅ Stable presentations
- ✅ Showcasing working features
- ✅ Customer demos
- ✅ Reference implementation
- ✅ Regression testing

### Running Both Simultaneously

**Yes, you can run both at the same time!**

```bash
# Check both are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "arcade|dev"

# Demo ports: 4000-4003
# Dev ports:  5000-5003
```

**Use cases:**
1. Demo v0.1.0-stable to stakeholders (ports 4000+)
2. Develop v0.2.0-neural in parallel (ports 5000+)
3. Compare behavior between versions
4. Regression testing (old vs new)

---

## Configuration Differences

### Development Environment

```yaml
Environment Variables:
  MACULA_REALM: "macula.arcade.dev"        # Separate realm
  LOG_LEVEL: "debug"                       # Verbose logging
  MACULA_QUIC_PORT: 5433-5436              # Different QUIC ports
  HEALTH_PORT: 9080-9083                   # Different health ports

Network:
  Subnet: 172.26.0.0/24                    # Separate network
  IPs: 172.26.0.10-13                      # Dev node IPs
```

### Demo Environment

```yaml
Environment Variables:
  MACULA_REALM: "macula.arcade"            # Production realm
  LOG_LEVEL: "info"                        # Standard logging
  MACULA_QUIC_PORT: 4433-4436              # Demo QUIC ports
  HEALTH_PORT: 8080-8083                   # Demo health ports

Network:
  Subnet: 172.25.0.0/24                    # Demo network
  IPs: 172.25.0.10-13                      # Demo node IPs
```

**They are completely isolated!**

---

## Troubleshooting

### Build Fails

**Check for syntax errors:**
```bash
cd system
mix compile
```

**Clean and rebuild:**
```bash
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml build --no-cache
docker compose -f docker-compose.dev.yml up -d
```

### Port Conflicts

**If dev ports are in use:**
```bash
# Check what's using ports
lsof -i :5000-5003

# Stop dev containers
docker compose -f docker-compose.dev.yml down
```

**If demo ports conflict with dev:**
They shouldn't! But if they do:
```bash
# Stop demo
docker compose -f docker-compose.demo.yml down

# Or change dev ports in docker-compose.dev.yml
```

### Health Checks Failing

**Check logs:**
```bash
docker compose -f docker-compose.dev.yml logs dev-gateway
```

**Verify health endpoint:**
```bash
curl http://localhost:9080/health
```

**Expected:** `{"status":"ok"}`

**Common issues:**
- Port conflict (unlikely with 9080+)
- Macula not starting (check QUIC cert issues)
- Phoenix not starting (check SECRET_KEY_BASE)

### Containers Keep Restarting

**Check logs for crash reason:**
```bash
docker compose -f docker-compose.dev.yml logs --tail=50 dev-gateway
```

**Common causes:**
- Missing dependencies (mix deps.get failed)
- Compilation errors (fix in system/)
- Runtime errors (check code changes)
- Certificate issues (TLS auto-gen may fail)

---

## Advanced Development

### Adding Dependencies

**Edit mix.exs:**
```elixir
# In system/mix.exs or system/apps/macula_arcade/mix.exs
defp deps do
  [
    {:macula_tweann, path: "../../macula-tweann"}  # Example
  ]
end
```

**Rebuild:**
```bash
docker compose -f docker-compose.dev.yml build --no-cache
docker compose -f docker-compose.dev.yml up -d
```

### Database Changes

**Create migration:**
```bash
# Inside dev container
docker exec -it dev-gateway /home/app/bin/macula_arcade eval 'IO.puts("test")'

# Or via local mix
cd system
mix ecto.gen.migration add_snakes_table
```

**Edit migration:**
```elixir
# system/apps/macula_arcade/priv/repo/migrations/xxx_add_snakes_table.exs
defmodule MaculaArcade.Repo.Migrations.AddSnakesTable do
  use Ecto.Migration

  def change do
    create table(:snakes) do
      add :name, :string
      add :generation, :integer
      timestamps()
    end
  end
end
```

**Rebuild to apply:**
```bash
docker compose -f docker-compose.dev.yml up --build -d
```

### Debugging with IEx

**Attach to running container:**
```bash
docker exec -it dev-gateway /home/app/bin/macula_arcade remote
```

**Run code:**
```elixir
iex> Application.spec(:macula_arcade, :vsn)
"0.1.0"

iex> MaculaArcade.Games.Coordinator.list_waiting_players()
```

---

## Performance Optimization

### Build Cache

Docker caches layers. To maximize cache hits:

**Good practice:**
```bash
# Only rebuild what changed
docker compose -f docker-compose.dev.yml up --build -d
```

**Full rebuild (slower, but clean):**
```bash
docker compose -f docker-compose.dev.yml build --no-cache
```

### Faster Rebuilds

**If only Elixir code changed (no deps):**
```bash
# Just restart containers (no rebuild)
docker compose -f docker-compose.dev.yml restart
```

**If only assets changed:**
```bash
# Rebuild is needed (npm assets)
docker compose -f docker-compose.dev.yml up --build -d
```

---

## Integration with TWEANN

### Adding macula-tweann Dependency

**1. Ensure macula-tweann is at same level:**
```
github.com/macula-io/
├── macula/
├── macula-arcade/
└── macula-tweann/       # Should be here
```

**2. Add to mix.exs:**
```elixir
# system/apps/macula_arcade/mix.exs
defp deps do
  [
    # ... existing deps
    {:macula_tweann, path: "../../../macula-tweann"}
  ]
end
```

**3. Rebuild:**
```bash
./deploy-dev.sh
```

**4. Verify:**
```bash
docker exec -it dev-gateway /home/app/bin/macula_arcade eval ':application.which_applications() |> IO.inspect()'
```

---

## Switching Between Environments

### Use Demo for Presentation

```bash
# Ensure demo is running
docker ps | grep arcade-gateway

# Access at http://localhost:4000
```

### Use Dev for Coding

```bash
# Start dev
./deploy-dev.sh

# Access at http://localhost:5000
```

### Run Both

```bash
# Both running simultaneously
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Should see:
# arcade-gateway  -> 4000, 8080, 4433
# dev-gateway     -> 5000, 9080, 5433
```

---

## Testing Workflow

### Manual Testing

1. **Make change in `./system/`**
2. **Rebuild dev:** `docker compose -f docker-compose.dev.yml up --build -d`
3. **Test at http://localhost:5000**
4. **Compare with demo at http://localhost:4000**

### Automated Testing

**Run tests before building:**
```bash
cd system
mix test
```

**Run tests in container:**
```bash
docker exec -it dev-gateway /home/app/bin/macula_arcade eval 'Mix.Task.run("test")'
```

---

## Cleanup

### Remove Dev Environment

```bash
# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Remove volumes too
docker compose -f docker-compose.dev.yml down -v

# Remove dev images
docker rmi macula-arcade:dev
```

### Keep Demo, Remove Dev

```bash
# Only remove dev
docker compose -f docker-compose.dev.yml down -v

# Demo remains at ports 4000+
docker ps | grep arcade-gateway
```

---

## Summary

**Development Environment:**
- Ports: 5000-5003 (HTTP), 5433-5436 (QUIC), 9080-9083 (Health)
- Network: 172.26.0.0/24
- Realm: macula.arcade.dev
- Source: Builds from `./system/`
- Logging: DEBUG level

**Demo Environment:**
- Ports: 4000-4003 (HTTP), 4433-4436 (QUIC), 8080-8083 (Health)
- Network: 172.25.0.0/24
- Realm: macula.arcade
- Source: Tagged v0.1.0-stable
- Logging: INFO level

**Both can run together for parallel development and demos!**

---

## Next Steps

Ready to start development:

```bash
# 1. Deploy dev environment
./deploy-dev.sh

# 2. Start coding neural snake (v0.2.0)
vim system/apps/macula_arcade/mix.exs  # Add macula-tweann

# 3. Follow NEURAL_SNAKE_VISION.md roadmap

# 4. Keep demo stable for presentations
```

**Happy coding!** 🚀
