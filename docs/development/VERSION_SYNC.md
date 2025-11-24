# Version Synchronization

**Last Updated:** 2025-01-21

## Current Version: v0.2.2

All version references have been synchronized across the project.

---

## Version Sources

| Source | Version | Status |
|--------|---------|--------|
| **system/mix.exs** | 0.2.2 | ✅ Synced |
| **Git Tag** | v0.2.2 | ✅ Exists |
| **Docker Image** | v0.2.2 | ✅ Built |
| **Demo Deployment** | v0.2.2-stable | ✅ Synced |
| **Documentation** | v0.2.2 | ✅ Synced |

---

## Release Roadmap

### Current Release
- **v0.2.2** (Current) - Basic Snake Battle Royale with mesh networking

### Planned Releases
- **v0.3.0** (3 weeks) - TWEANN integration, training ground, self-play
- **v0.4.0** (4 weeks) - Neural gameplay, UI, modes, export/import
- **v0.5.0** (3 weeks) - Distributed training via mesh
- **v1.0.0** (4 weeks) - Advanced RL, production-ready

---

## Version Management Guidelines

### When Bumping Versions

1. **Update mix.exs:**
   ```elixir
   # system/mix.exs
   version: "0.3.0"
   ```

2. **Create Git Tag:**
   ```bash
   git tag -a v0.3.0 -m "Release v0.3.0: TWEANN Foundation"
   git push origin v0.3.0
   ```

3. **Build Docker Image:**
   ```bash
   docker build -t macula-arcade:v0.3.0 -f system/Dockerfile system
   docker tag macula-arcade:v0.3.0 macula-arcade:latest
   ```

4. **Update Documentation:**
   - NEURAL_SNAKE_VISION.md (release headers)
   - DEMO_DEPLOYMENT.md (version reference)
   - ENVIRONMENTS.md (version table)
   - README.md (if applicable)

5. **Update Deployment Scripts:**
   - deploy-demo.sh (VERSION variable)
   - docker-compose.demo.yml (image tags)

---

## Tagging Convention

- **Stable releases:** `v0.2.2`, `v0.3.0`, `v1.0.0`
- **Demo tags:** `v0.2.2-stable`, `v0.3.0-stable`
- **Development:** `dev` (no version tag)

---

## Checking Current Versions

### Check mix.exs
```bash
grep "version:" system/mix.exs
```

### Check Git Tags
```bash
git tag -l | sort -V | tail -5
```

### Check Docker Images
```bash
docker images | grep macula-arcade
```

### Check Running Container
```bash
docker exec arcade-gateway /home/app/bin/macula_arcade eval "IO.puts(Application.spec(:macula_arcade, :vsn))"
```

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| v0.2.2 | 2025-11-19 | Current stable release |
| v0.2.1 | 2025-11-19 | Previous release |
| v0.1.0 | Earlier | Initial release (outdated in mix.exs, now synced to v0.2.2) |

---

**All versions are now synchronized at v0.2.2!** ✅
