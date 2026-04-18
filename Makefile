.PHONY: up pull up-pull build up-build logs reset-prefix-help

# Start stack (build first if you use the default local image: tag from compose)
up:
	docker compose up -d

# When compose `image:` points at a registry, pull then start
up-pull: pull
	docker compose up -d

pull:
	docker compose pull

# Local image build (no registry)
build:
	docker compose build --no-cache

up-build: build
	docker compose up -d

logs:
	docker logs --tail 200 -f remote-desktop 2>&1

reset-prefix-help:
	@echo "Run as root inside the container (or from host with docker exec) to wipe Wine prefix + corefonts stamp:"
	@echo "  docker exec remote-desktop rm -rf /config/wine-gameforge"
	@echo "  docker exec remote-desktop rm -f /config/gameforge/.winetricks-corefonts.done"
	@echo "Paths differ if you overrode GAMEFORGE_WINEPREFIX / GAMEFORGE_DIR — see docs/TROUBLESHOOTING.md"
