# docker-gameforge

**Remote Linux desktop** in a browser via [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/) (`debian-xfce`, **Selkies** / HTTPS UI), plus **[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)** from the official GitHub **Debian 13** packages (`umu-launcher` + `python3-umu-launcher`, provides **`umu-run`**). The image enables **i386** and installs the 32-bit Mesa libraries those packages require (`libgl1-mesa-dri:i386`, `libglx-mesa0:i386`).

**Fonts:** the image pre-accepts the MS Core Fonts EULA and installs **`ttf-mscorefonts-installer`** (Arial, Times New Roman, Courier, etc.), plus metric-compatible **`fonts-croscore`** and **`fonts-liberation`**, and **`fonts-noto-color-emoji`** for color emoji where **fontconfig**/apps pick it up. **Wine** UIs may still use prefix fonts for emoji.

### Winetricks (Wine prefix)

The image installs **`wine`**, **`wine32`**, and **`winetricks`**. **Do not** run winetricks against a Proton prefix with **`/usr/bin/wine`** — that mixes Wine builds. Here, **`gameforge-autostart.sh`** and **`run-winetricks.sh`** set **`WINE`** to **Proton’s `files/bin/wine`** (resolved by **`resolve-proton-wine.sh`**: **`PROTONPATH`** if set — absolute or resolvable relative to cwd / **`$HOME`** — else newest **`*/files/bin/wine`** under **`~/.local/share/umu`**, and only if none there, under **`~/.local/share/Steam/compatibilitytools.d`**). Symlink **`wine`** entries are included. **`PROTONPATH`** wins over **`GAMEFORGE_PROTONPATH`** when both are set. If Proton is not on disk yet, corefonts is skipped until the next session (or the second pass in autostart after **`umu-run`** on the installer).

**`gameforge-autostart.sh`** runs **`winetricks -q corefonts`** **once** (needs network the first time), then creates **`GAMEFORGE_DIR/.winetricks-corefonts.done`**. To skip: **`GAMEFORGE_WINETRICKS_COREFONTS=false`**. To retry: delete that stamp file.

Manual runs: **`/usr/local/bin/run-winetricks.sh`** (same **`WINEPREFIX`** / **`GAMEID`** / **`STORE`** / **`PROTONPATH`** as **`umu-run`**; override prefix with **`GAMEFORGE_WINEPREFIX`**, optional **`GAMEFORGE_PROTONPATH`**), e.g. **`run-winetricks.sh --gui`**.

**Winetricks** does not ship a verb for **Segoe UI Emoji**; **`corefonts`** covers the usual MS web fonts (Arial, Times, Courier, …) inside the prefix. Color emoji on the **Linux** desktop still comes from **`fonts-noto-color-emoji`**. If a **Wine** app still shows emoji boxes, it is usually asking for a Windows emoji font — that is outside what **`corefonts`** provides.

## Run

```bash
docker compose up --build
```

Open **[https://localhost:3001/](https://localhost:3001/)** (accept the self-signed certificate warning).

In a terminal inside the desktop:

```bash
umu-run --help
```

### Time zone (Gameforge / Wine)

[docker-compose.yml](docker-compose.yml) uses **`TZ=Europe/Warsaw`** so the whole container (and **Wine/Proton** via the `TZ` variable) uses Central European time. **`Etc/UTC`** often surfaces in apps as **Atlantic/Reykjavik**-style offsets. **`run-gameforge-client.sh`** and **`gameforge-autostart.sh`** set **`TZ="${GAMEFORGE_TZ:-${TZ:-Europe/Warsaw}}"`** so you can override with **`GAMEFORGE_TZ`** for Gameforge only. Recreate or restart the stack after changing `TZ`; an existing Wine prefix usually picks up the new zone on the next run.

**Why the launcher might show `Europe/Budapest`:** **`Europe/Warsaw`** and **`Europe/Budapest`** follow the **same** CET/CEST rules today. Many stacks (ICU, Chromium, .NET) **canonicalize** equivalent IANA zones to **one display ID** — often Budapest — even when Linux `TZ` is Warsaw. If **wall-clock time** matches Poland, configuration is fine; only the **reported zone name** may differ.

### Screen size (fingerprint / work area)

Launchers often read **screen or viewport size**, not raw **1920×1080**. In Webtop, **XFCE** (panel ~24–32px) and **Windows** (pasek ~40–48px) subtract different amounts, so you can see e.g. **1920×1053** in the container vs **1920×1032** in a Windows browser — this is normal.

You can **lock the Selkies / X11 resolution** with environment variables (see [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/)):

- **`SELKIES_MANUAL_WIDTH`** / **`SELKIES_MANUAL_HEIGHT`** — fixed session size (enables manual resolution mode).
- **`MAX_RESOLUTION`** — same **WxH** as the manual size so the virtual framebuffer matches (recommended for X11 + GPU docs).

**Heuristic:** if **`h_reported`** is what the app shows now and you want **`h_target`**, estimate panel height **`p ≈ H_virtual − h_reported`**, then set **`SELKIES_MANUAL_HEIGHT ≈ h_target + p`** and **`MAX_RESOLUTION=1920x…`** to the same **W×H**. [docker-compose.yml](docker-compose.yml) uses **`GAMEFORGE_XFCE_PANEL_SIZE=47`** for the XFCE panel (with **`1920×1080`** virtual height, work area below the panel is about **1033 px** tall). Selkies/video may still **round** dimensions; verify with **`xrandr`**.

**XFCE panel:** **`/etc/xdg/autostart/xfce-panel.desktop`** runs **`xfce-panel-autostart.sh`**, which reads **`GAMEFORGE_XFCE_PANEL_SIZE`** (absolute thickness in px for each panel that has `/size`). Unset or empty = no change.

### WebGL (Chromium in the remote desktop)

The image installs **Mesa** (**`libgl1-mesa-dri`**, **`libegl-mesa0`**, **`libgles2`**, **`mesa-vulkan-drivers`**, **`libvulkan1`**). Without a passed-through GPU, Chromium usually ends up on **llvmpipe** (software OpenGL via ANGLE). Chromium **blocklists WebGL on software renderers** by default (“WebGL1 blocklisted” in `chrome://gpu`); **`/etc/chromium.d/gameforge-webgl`** therefore adds **`--ignore-gpu-blocklist`** so WebGL can run on the CPU (slower, higher load). It also keeps **`--disable-gpu-sandbox`** and **`--disable-dev-shm-usage`** for typical Docker/X11 setups.

For **hardware** WebGL, mount **`/dev/dri`** (see [docker-compose.yml](docker-compose.yml)) and follow [LinuxServer Webtop — GPU](https://docs.linuxserver.io/images/docker-webtop/). **`debian-xfce`** is mainly **X11**; real GPU + DRI avoids the software-renderer blocklist entirely.

### Autostart (Gameforge installer)

**`/etc/xdg/autostart/*.desktop`** is only for **programs that start with the session** — XFCE does **not** copy those files onto the desktop as icons. Your home (and Desktop) live under **`/config`**, so **`gameforge-autostart.sh`** refreshes **`/config/Desktop/Gameforge Client.desktop`** once **`gfclient.exe`** exists, and always writes **`/config/Desktop/Wine Explorer.desktop`** ( **`run-wine-explorer.sh`** → **`explorer.exe`** via **`umu-run`**).

To start the client yourself: **`/usr/local/bin/run-gameforge-client.sh`** (same as double‑clicking **Gameforge Client** on the desktop). **Wine Explorer:** **`/usr/local/bin/run-wine-explorer.sh`** (or the **Wine Explorer** icon). That script passes the same Chromium baseline flags as **`/etc/chromium.d/gameforge-webgl`** (`--disable-gpu-sandbox`, `--disable-dev-shm-usage`, `--ignore-gpu-blocklist`) to **`gfclient.exe`** for the embedded **CEF** UI. Disable with **`GAMEFORGE_CEF_CHROME_FLAGS=0`**. **Stdout/stderr** are appended to **`/config/Desktop/gameforge-client.log`** (override with **`GAMEFORGE_CLIENT_LOG`**); from a terminal, output is also shown (**`tee`**).

XFCE loads **`/etc/xdg/autostart/gameforge-autostart.desktop`**, which runs **`/usr/local/bin/gameforge-autostart.sh`**. On each session start it:

1. Skips if **`GAMEFORGE_AUTOSTART`** is not `true` (see [docker-compose.yml](docker-compose.yml)).
2. Runs **`winetricks -q corefonts`** once until **`GAMEFORGE_DIR/.winetricks-corefonts.done`** exists (unless **`GAMEFORGE_WINETRICKS_COREFONTS=false`**), using **Proton’s `wine`** only — see **Winetricks** above.
3. If **`gfclient.exe`** (or another known client name) already exists under the Wine prefix — starts **`run-gameforge-client.sh`** in the background instead of the installer.
4. Otherwise downloads **`GameforgeInstaller.exe`** (default URL from compose; override with **`GAMEFORGE_DOWNLOAD_URL`**) into **`GAMEFORGE_DIR`** (default **`/config/gameforge`**) and runs **`umu-run`** on it.

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
