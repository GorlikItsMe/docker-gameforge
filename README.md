# docker-gameforge

**Remote Linux desktop** in a browser via [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/) (`debian-xfce`, **Selkies** / HTTPS UI), plus **[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)** from the official GitHub **Debian 13** packages (`umu-launcher` + `python3-umu-launcher`, provides **`umu-run`**). The image enables **i386** and installs the 32-bit Mesa libraries those packages require (`libgl1-mesa-dri:i386`, `libglx-mesa0:i386`).

## Run

```bash
docker compose up --build
```

Open **[https://localhost:3001/](https://localhost:3001/)** (accept the self-signed certificate warning).

In a terminal inside the desktop:

```bash
umu-run --help
```

### WebGL (Chromium in the remote desktop)

The image installs **Mesa** (**`libgl1-mesa-dri`**, **`libegl-mesa0`**, **`libgles2`**, **`mesa-vulkan-drivers`**, **`libvulkan1`**). Without a passed-through GPU, Chromium usually ends up on **llvmpipe** (software OpenGL via ANGLE). Chromium **blocklists WebGL on software renderers** by default (“WebGL1 blocklisted” in `chrome://gpu`); **`/etc/chromium.d/gameforge-webgl`** therefore adds **`--ignore-gpu-blocklist`** so WebGL can run on the CPU (slower, higher load). It also keeps **`--disable-gpu-sandbox`** and **`--disable-dev-shm-usage`** for typical Docker/X11 setups.

For **hardware** WebGL, mount **`/dev/dri`** (see [docker-compose.yml](docker-compose.yml)) and follow [LinuxServer Webtop — GPU](https://docs.linuxserver.io/images/docker-webtop/). **`debian-xfce`** is mainly **X11**; real GPU + DRI avoids the software-renderer blocklist entirely.

### Autostart (Gameforge installer)

**`/etc/xdg/autostart/*.desktop`** is only for **programs that start with the session** — XFCE does **not** copy those files onto the desktop as icons. Your home (and Desktop) live under **`/config`**, so a visible launcher is written to **`/config/Desktop/Gameforge Client.desktop`** once **`gfclient.exe`** exists (refreshed on each login).

To start the client yourself: **`/usr/local/bin/run-gameforge-client.sh`** (same as double‑clicking **Gameforge Client** on the desktop). That script passes the same Chromium baseline flags as **`/etc/chromium.d/gameforge-webgl`** (`--disable-gpu-sandbox`, `--disable-dev-shm-usage`, `--ignore-gpu-blocklist`) to **`gfclient.exe`** for the embedded **CEF** UI. Disable with **`GAMEFORGE_CEF_CHROME_FLAGS=0`**. **Stdout/stderr** are appended to **`/config/Desktop/gameforge-client.log`** (override with **`GAMEFORGE_CLIENT_LOG`**); from a terminal, output is also shown (**`tee`**).

XFCE loads **`/etc/xdg/autostart/gameforge-autostart.desktop`**, which runs **`/usr/local/bin/gameforge-autostart.sh`**. On each session start it:

1. Skips if **`GAMEFORGE_AUTOSTART`** is not `true` (see [docker-compose.yml](docker-compose.yml)).
2. Skips if it already finds a plausible Gameforge client **`.exe`** under **`GAMEFORGE_WINEPREFIX`** (default **`/config/wine-gameforge`**).
3. Otherwise downloads **`GameforgeInstaller.exe`** (default URL from compose; override with **`GAMEFORGE_DOWNLOAD_URL`**) into **`GAMEFORGE_DIR`** (default **`/config/gameforge`**) and runs **`umu-run`** on it.

**`DISPLAY`** is taken from the session or the first **`/tmp/.X11-unix`** socket (Webtop often uses **`:1`**). A trace is appended to **`/config/Desktop/gameforge-autostart.log`**.

If the installer does not appear: read that log, then **`docker logs remote-desktop`**. Rebuild the image after editing files under **`root/`** — bind-mounted **`/config`** does not replace **`/etc/xdg/autostart`** in the image.

**Proton / graphics:** Compose sets **`PROTON_USE_WINED3D=1`** so the installer uses **OpenGL (WineD3D)** instead of **DXVK/Vulkan**. On Selkies/Webtop, Vulkan often lacks **`VK_KHR_surface`**, which shows up as *“Required Vulkan extension VK_KHR_surface not supported”* and crashes the installer UI. For titles that need DXVK with a real GPU, try **`PROTON_USE_WINED3D=0`** plus **`/dev/dri`** (or an NVIDIA runtime) and a working Vulkan stack.

Manual run (same as autostart): `LD_PRELOAD= umu-run /config/gameforge/GameforgeInstaller.exe` — clearing **`LD_PRELOAD`** avoids 32-bit vs 64-bit preload noise from Selkies shims.

See [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) for **`PROTONPATH`** (e.g. **`GE-Proton`**).

### Docker and pressure-vessel

`umu-run` uses bubblewrap (**bwrap**) and **user namespaces**. Docker’s default seccomp profile blocks that, which shows up as *“bwrap: No permissions to create a new namespace”*. [docker-compose.yml](docker-compose.yml) sets **`security_opt: seccomp:unconfined`** so the installer and games can run — see [umu-launcher#156](https://github.com/Open-Wine-Components/umu-launcher/issues/156).

On some hosts you may also need **`kernel.unprivileged_userns_clone=1`** (Linux) if the error persists outside seccomp; Docker Desktop / WSL2 usually only needs the compose change above.

## Compose

- **`/config`** — persistent home for user `abc`.
- **`shm_size: 1gb`** — recommended by Webtop.

## License

MIT
