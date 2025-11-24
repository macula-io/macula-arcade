# Docker Build Configuration

This directory contains three Dockerfiles for different use cases:

## Dockerfile.dev (Development with Local Macula)

**Purpose:** Development with local macula repository (for testing unreleased macula changes)

**Used by:**
- `docker/dev/docker-compose.yml` - Development environment

**Characteristics:**
- Base: Ubuntu 22.04 (jammy)
- **Uses local macula from path** (`/macula` in build context)
- Mix path dependency: `{:macula, path: "/macula"}`
- Pre-built certificates from `priv/certs/`
- Health check configured
- Allows testing macula changes before publishing to hex

**Build command:**
```bash
docker build -f Dockerfile.dev \
  --build-context macula=../../../macula \
  -t macula-arcade:dev .
```

## Dockerfile (Testing/Demo)

**Purpose:** Testing with published macula from hex.pm

**Used by:**
- `docker/prod/docker-compose.yml` - Production testing environment (when testing before CI/CD)

**Characteristics:**
- Base: Ubuntu 22.04 (jammy)
- **Includes pre-built certificates** from `priv/certs/`
- Direct CMD start (no entrypoint)
- Includes `mix assets.setup` step
- No health check (handled by docker-compose)
- Simpler, faster for local iteration

**Build command:**
```bash
docker build -f Dockerfile -t macula-arcade:dev .
```

## Dockerfile.prod (Production/CI/CD)

**Purpose:** Production deployments via CI/CD

**Used by:**
- `.github/workflows/docker-publish.yml` - GitHub Actions
- Docker Hub automated builds
- Production deployments

**Characteristics:**
- Base: Debian Bookworm Slim (smaller, more secure)
- **Runtime certificate generation** via entrypoint script
- Health check configured (30s interval)
- HEALTHCHECK directive for container orchestration
- Optimized for multi-arch builds (amd64/arm64)
- Uses `docker-entrypoint.sh` for runtime setup

**Build command:**
```bash
docker build -f Dockerfile.prod -t macula-arcade:latest .
```

## Key Differences

| Feature | Dockerfile | Dockerfile.prod |
|---------|-----------|-----------------|
| **Base Image** | Ubuntu 22.04 | Debian Bookworm Slim |
| **Size** | Larger | Smaller (~20% reduction) |
| **Certificates** | Copied from priv/ | Generated at runtime |
| **Entrypoint** | None | docker-entrypoint.sh |
| **Health Check** | No | Yes (30s interval) |
| **Assets** | setup + deploy | deploy only |
| **Use Case** | Development | Production |

## Which to Use?

### Use `Dockerfile` when:
- Local development with docker-compose
- Testing with pre-generated certificates
- Quick iteration and debugging
- Running in docker/dev/ or docker/test/

### Use `Dockerfile.prod` when:
- Publishing to Docker Hub
- CI/CD pipelines
- Production deployments
- Multi-architecture builds
- Need health checks and runtime cert generation

## Certificate Handling

### Development (Dockerfile)
Expects certificates in `priv/certs/`:
```
priv/certs/
├── server-cert.pem
└── server-key.pem
```

Certificates are copied during build:
```dockerfile
COPY --from=builder /app/priv/certs/server-cert.pem /opt/macula/certs/cert.pem
COPY --from=builder /app/priv/certs/server-key.pem /opt/macula/certs/key.pem
```

### Production (Dockerfile.prod)
Generates certificates at runtime if not provided:
- Empty `/opt/macula/certs/` created during build
- `docker-entrypoint.sh` checks for certs and generates if missing
- Allows mounting external certs via volumes

## Build Context

Both Dockerfiles expect to be built from the `system/` directory:

```bash
# From project root
docker build -f system/Dockerfile system/
docker build -f system/Dockerfile.prod system/

# From system/ directory
docker build -f Dockerfile .
docker build -f Dockerfile.prod .
```

## Multi-Architecture Builds

`Dockerfile.prod` is optimized for multi-arch builds:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.prod \
  -t maculacid/macula-arcade:latest \
  --push \
  .
```

## Related Files

- `docker-entrypoint.sh` - Production entrypoint script
- `entrypoint.sh` - Legacy entrypoint (may be unused)
- `../docker/dev/docker-compose.yml` - Uses Dockerfile
- `../docker/test/docker-compose.yml` - Uses Dockerfile
- `../.github/workflows/docker-publish.yml` - Uses Dockerfile.prod
