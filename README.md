# docker-gameforge

**Remote Linux desktop** in a browser via [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/) (`debian-xfce`, **Selkies** / HTTPS UI), plus **[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)** from the official GitHub **Debian 13** packages (`umu-launcher` + `python3-umu-launcher`, provides `**umu-run`**). The image enables **i386** and installs the 32-bit Mesa libraries those packages require (`libgl1-mesa-dri:i386`, `libglx-mesa0:i386`).

## Run

```bash
docker compose up --build
```

Open **[https://localhost:3001/](https://localhost:3001/)** (accept the self-signed certificate warning).

In a terminal inside the desktop:

```bash
umu-run --help
```

### Autostart (browser)

XFCE loads `**/etc/xdg/autostart/docker-browser-autostart.desktop**`. The script `**/usr/local/bin/docker-browser-autostart.sh**` honors `**BROWSER_AUTOSTART**` (see [docker-compose.yml](docker-compose.yml)), sets `**DISPLAY**` from the session if present or from the first `**/tmp/.X11-unix**` socket (Webtop often uses `**:1**`), otherwise `**:0**`. It appends a trace to `**/config/Desktop/browser-autostart.log**` (which backend ran, env snapshot).

If nothing opens: read that log first, then `docker logs remote-desktop` (harmless **login1** / **X11-unix** noise in containers is normal). Rebuild the image after editing files under `**root/`** — bind-mounted `**/config**` does not replace image paths like `**/etc/xdg/autostart**`.

Running Windows games still requires a **Proton/UMU-Proton** build and correct `PROTONPATH` / `STEAM_COMPAT_DATA_PATH` (see upstream docs). This image only installs **umu** itself, not GE-Proton or Steam.

### Docker and pressure-vessel

`umu-run` uses bubblewrap / user namespaces. In Docker you may need a looser seccomp profile (e.g. `security_opt: [seccomp:unconfined]`) or a custom profile — see [umu-launcher#156](https://github.com/Open-Wine-Components/umu-launcher/issues/156).

## Compose

- `**/config`** — persistent home for user `abc`.
- `**shm_size: 1gb`** — recommended by Webtop.

## License

MIT