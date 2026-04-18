# docker-gameforge

**Browser desktop** (LinuxServer **Webtop** / Selkies) with **[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)** (`umu-run`) and **Gameforge** autostart helpers.

## Quick start

1. Clone the repo and enter the directory.
2. **Start:** `docker compose up -d` (after a local **`docker compose build`** if you use the default **`docker-gameforge:latest`** tag). With a registry **`image:`**, run **`docker compose pull`** first (or **`make up-pull`** in the [Makefile](Makefile)).
3. Open **`https://<host>:3001/`** (accept the self-signed cert warning for HTTPS).
4. Wait for the session; the installer may start automatically. Logs: **`/config/Desktop/gameforge-autostart.log`** (inside the volume / desktop).
5. **Manual `umu-run` test** (must **not** be root — Webtop user is usually **`abc`**):  
   `docker exec -it -u abc remote-desktop bash -lc 'LD_PRELOAD= umu-run --help'`

**First-time / offline / fork without GHCR:** build locally, then start (tags the image name from compose):

```bash
docker compose build --no-cache
docker compose up -d
```

**Change defaults:** edit **`environment:`** in [docker-compose.yml](docker-compose.yml) (runtime overrides). **`TZ`**, Selkies resolution, **`PROTON_USE_WINED3D`**, etc. also have defaults in the **[Dockerfile](Dockerfile)** (`ENV`). Installer download URL defaults in **`gameforge-autostart.sh`**; override with **`GAMEFORGE_DOWNLOAD_URL`** if needed. Optional **`env_file`** (e.g. **`local.env`**) can be added under **`services.desktop`** if you prefer secrets/overrides outside git — see [Compose env_file order](https://docs.docker.com/compose/environment-variables/set-environment-variables/).

**Fork / own registry:** set **`image:`** in [docker-compose.yml](docker-compose.yml) (default **`docker-gameforge:latest`** matches a local **`compose build`**).

## Why compose looks “heavy”

`umu-run` / Proton use **bubblewrap** and user namespaces. On many hosts you need **`seccomp:unconfined`**, **`apparmor:unconfined`**, **`userns_mode: "host"`**, and often **`privileged: true`**, plus **`uidmap`** / subuid setup **inside the image**. Details, diagnostics, and host sysctl hints are in **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

## Docs

| Doc | Purpose |
|-----|---------|
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Winetricks, Wine prefix, resolution, WebGL, autostart flow, pressure-vessel / bwrap, `docker exec`, reset prefix |
| [Dockerfile](Dockerfile) | Image defaults: `TZ`, Selkies size, `MAX_RESOLUTION`, `PROTON_USE_WINED3D`, etc. |
| [docker-compose.yml](docker-compose.yml) | Runtime `environment:` (overrides image `ENV`), volumes, `security_opt`, `privileged`, etc. |

## License

MIT
