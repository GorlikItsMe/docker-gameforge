# docker-gameforge — troubleshooting and reference

Detailed behavior, environment variables, and workarounds. For a minimal “get running” path, see the [README](../README.md).

## Contents

- [docker-gameforge — troubleshooting and reference](#docker-gameforge--troubleshooting-and-reference)
  - [Contents](#contents)
  - [Fonts](#fonts)
  - [Winetricks and Wine prefix](#winetricks-and-wine-prefix)
  - [WebGL (Chromium)](#webgl-chromium)
  - [Autostart (Gameforge installer)](#autostart-gameforge-installer)
  - [Docker and pressure-vessel (bwrap / umu-run)](#docker-and-pressure-vessel-bwrap--umu-run)
  - [Compose volume and shm](#compose-volume-and-shm)
  - [Reset Wine prefix (32-bit error)](#reset-wine-prefix-32-bit-error)
  - [Environment variables (quick reference)](#environment-variables-quick-reference)

---

## Fonts

The image pre-accepts the MS Core Fonts EULA and installs **`ttf-mscorefonts-installer`** (Arial, Times New Roman, Courier, etc.), plus metric-compatible **`fonts-croscore`** and **`fonts-liberation`**, and **`fonts-noto-color-emoji`** for color emoji where **fontconfig**/apps pick it up. **Wine** UIs may still use prefix fonts for emoji.

---

## Winetricks and Wine prefix

The image installs **`wine`**, **`wine32`**, and **`winetricks`**. **Do not** run winetricks against a Proton prefix with **`/usr/bin/wine`** — that mixes Wine builds. Here, **`gameforge-autostart.sh`** and **`run-winetricks.sh`** set **`WINE`** to **Proton’s `files/bin/wine`** (resolved by **`resolve-proton-wine.sh`**: **`PROTONPATH`** if set — absolute or resolvable relative to cwd / **`$HOME`** — else newest **`*/files/bin/wine`** under **`~/.local/share/umu`**, and only if none there, under **`~/.local/share/Steam/compatibilitytools.d`**). Symlink **`wine`** entries are included. **`PROTONPATH`** wins over **`GAMEFORGE_PROTONPATH`** when both are set. If Proton is not on disk yet, corefonts is skipped until the prefix exists; on a clean install that is **after** the first **`umu-run`** (see stamp / second **`maybe_winetricks`** pass in **`gameforge-autostart.sh`**).

**`gameforge-autostart.sh`** runs **`winetricks -q corefonts`** **once** after the Wine prefix exists (needs network the first time), then creates **`GAMEFORGE_DIR/.winetricks-corefonts.done`**. On a **clean** volume it **skips** winetricks until **`umu-run`** has created **`system.reg`**, so the prefix stays **64-bit (WoW64)**; the second pass (after the installer) installs fonts. Scripts export **`WINEARCH=win64`**. To skip corefonts: **`WINETRICKS_COREFONTS=false`**. To retry: delete that stamp file.

Manual runs: **`/usr/local/bin/run-winetricks.sh`** (same **`WINEPREFIX`** / **`WINEARCH`** / **`GAMEID`** / **`STORE`** / **`PROTONPATH`** as **`umu-run`**; override prefix with **`GAMEFORGE_WINEPREFIX`**, optional **`GAMEFORGE_PROTONPATH`**), e.g. **`run-winetricks.sh --gui`**.

**Winetricks** does not ship a verb for **Segoe UI Emoji**; **`corefonts`** covers the usual MS web fonts (Arial, Times, Courier, …) inside the prefix. Color emoji on the **Linux** desktop still comes from **`fonts-noto-color-emoji`**. If a **Wine** app still shows emoji boxes, it is usually asking for a Windows emoji font — that is outside what **`corefonts`** provides.

See [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) for **`PROTONPATH`** (e.g. **`GE-Proton`**).

---

## WebGL (Chromium)

The image installs **Mesa** (**`libgl1-mesa-dri`**, **`libegl-mesa0`**, **`libgles2`**, **`mesa-vulkan-drivers`**, **`libvulkan1`**). Without a passed-through GPU, Chromium usually ends up on **llvmpipe** (software OpenGL via ANGLE). Chromium **blocklists WebGL on software renderers** by default (“WebGL1 blocklisted” in `chrome://gpu`); **`/etc/chromium.d/gameforge-webgl`** therefore adds **`--ignore-gpu-blocklist`** so WebGL can run on the CPU (slower, higher load). It also keeps **`--disable-gpu-sandbox`** and **`--disable-dev-shm-usage`** for typical Docker/X11 setups.

For **hardware** WebGL, mount **`/dev/dri`** (see [docker-compose.yml](../docker-compose.yml)) and follow [LinuxServer Webtop — GPU](https://docs.linuxserver.io/images/docker-webtop/). **`debian-xfce`** is mainly **X11**; real GPU + DRI avoids the software-renderer blocklist entirely.

---

## Autostart (Gameforge installer)

**`/etc/xdg/autostart/gameforge-autostart.desktop`** runs **`/usr/local/bin/gameforge-autostart.sh`** on each XFCE login. That is **session autostart**, not “icons appear by magic”: Desktop lives under **`/config`**, and the script keeps **`/config/Desktop/Gameforge Client.desktop`** (after **`gfclient.exe`** exists) and **`Wine Explorer.desktop`** in sync.

**Run by hand:** **`/usr/local/bin/run-gameforge-client.sh`** · **`/usr/local/bin/run-wine-explorer.sh`**. The client wrapper applies the same Chromium flags as **`/etc/chromium.d/gameforge-webgl`** for embedded CEF (**`GAMEFORGE_CEF_CHROME_FLAGS=0`** turns that off). Logs: **`/config/Desktop/gameforge-client.log`** (**`GAMEFORGE_CLIENT_LOG`**); terminal runs also **`tee`** to the screen.

**Flow** (when **`GAMEFORGE_AUTOSTART=true`**, see **`environment:`** in [docker-compose.yml](../docker-compose.yml)): optional one-time **corefonts** via Proton’s Wine (see **Winetricks** above) → if the client exe is already in the prefix, start **`run-gameforge-client.sh`** → else download **`GameforgeInstaller.exe`** into **`GAMEFORGE_DIR`** (URL from **`gameforge-autostart.sh`**, optional **`GAMEFORGE_DOWNLOAD_URL`**) and **`umu-run`** it. **`DISPLAY`** from the session or **`/tmp/.X11-unix`** (often **`:1`**). Autostart trace: **`/config/Desktop/gameforge-autostart.log`**.

**Nothing on screen?** That log, then **`docker logs remote-desktop`**. After editing **`root/`**, **rebuild the image** — **`/config`** does not replace **`/etc/xdg/autostart`**.

**Graphics:** default **`PROTON_USE_WINED3D=1`** avoids broken Vulkan on Webtop (e.g. missing **`VK_KHR_surface`** / installer UI crash). Real GPU + DXVK: try **`PROTON_USE_WINED3D=0`** and DRI / NVIDIA pass-through with a working Vulkan stack.

**Installer manually** (clears Selkies **`LD_PRELOAD`** noise): `LD_PRELOAD= umu-run /config/gameforge/GameforgeInstaller.exe`

---

## Docker and pressure-vessel (bwrap / umu-run)

`umu-run` uses **bubblewrap** (`bwrap`) and **user namespaces** via Steam’s **pressure-vessel** sandbox.

[docker-compose.yml](../docker-compose.yml) sets:

1. **`seccomp:unconfined`** — Docker’s default seccomp profile otherwise blocks the syscalls needed for nested namespaces. Symptom: *“bwrap: No permissions to create a new namespace”*. See [umu-launcher#156](https://github.com/Open-Wine-Components/umu-launcher/issues/156).

2. **`apparmor:unconfined`** — On many **Ubuntu/Debian** servers, the **`docker-default`** AppArmor profile still blocks mount propagation inside the container. Symptom: *“bwrap: Failed to make / slave: Permission denied”* from `pressure-vessel-wrap`. Disabling AppArmor confinement for **this** container fixes that without turning off AppArmor on the whole host.

If **`apparmor:unconfined`** is not supported on your host (rare), remove that line from compose or override it in a local override file.

3. **`userns_mode: "host"`** — If you see *“bwrap: **setting up uid map: Permission denied**”* and the daemon uses **user-namespace remapping** (`userns-remap` / rootless), **pressure-vessel** cannot set up a second uid map for **bubblewrap**. Opting this service into the **host** user namespace fixes that. On a daemon **without** remap, Docker ignores this option.

**Check on the server:** `docker info` and look for **User Namespace** / **userns** / **rootless** hints; see also `/etc/docker/daemon.json` for `"userns-remap"`.

4. **`/etc/subuid` + `/etc/subgid` + `uidmap`** — Another common cause of *“bwrap: **setting up uid map: Permission denied**”* (even with **`privileged: true`**) is missing **subordinate UID/GID** ranges for the **desktop user** (`abc` / **`CUSTOM_USER`**, from **`PUID`**). **pressure-vessel** invokes **`newuidmap`**, which refuses if there is no matching line in **`/etc/subuid`**. The image installs **`uidmap`** and **`/etc/cont-init.d/10-gameforge-subuid`** to append **`username:100000:65536`** on container start when missing. **Rebuild the image** after pulling if you changed Dockerfile/init.

   Quick check **inside** the container: `docker exec remote-desktop cat /etc/subuid` should list your user (e.g. **`abc:100000:65536`**), and `ls -la /usr/bin/newuidmap` should show **setuid** (`s` bit).

**Still “setting up uid map” after a rebuild:** on **Ubuntu 24.04+** the host may enforce **`kernel.apparmor_restrict_unprivileged_userns=1`**, which can still block **bubblewrap** for unprivileged users. On the **host**:

```bash
sysctl kernel.apparmor_restrict_unprivileged_userns
# if it prints 1:
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/60-apparmor-userns.conf
sudo sysctl -p /etc/sysctl.d/60-apparmor-userns.conf
sudo systemctl restart docker
```

(Security tradeoff: relaxes a host-wide hardening knob; avoid on untrusted multi-tenant servers.)

**`privileged: true`** is a broad Docker-side relaxation for **this** service; it does **not** replace **`/etc/subuid`** or the host sysctl above when those are the limiting factor.

**Manual `docker exec` tests:** `docker exec` defaults to **root**. **`umu-run` refuses root** (*“This script should never be run as the root user”*). Run as the Webtop user (default **`abc`**, PUID **1000**):

```bash
docker exec -it -u abc remote-desktop bash -lc 'LD_PRELOAD= umu-run /config/gameforge/GameforgeInstaller.exe 2>&1 | tail -n 40'
```

(If you set **`CUSTOM_USER`**, use that name instead of **`abc`**.)

**Other:** ensure `kernel.unprivileged_userns_clone=1` where applicable. **SELinux:** try **`security_opt: label:disable`**. **Kubernetes:** often needs **`privileged: true`** or a custom policy anyway.

---

## Compose volume and shm

- **`/config`** — persistent home for user `abc` (LinuxServer default).
- **`shm_size: 1gb`** — recommended by Webtop.

---

## Reset Wine prefix (32-bit error)

**Wine error:** *“`…` is a 32-bit installation, it cannot support 64-bit applications”* — the prefix was created as **32-bit-only** (e.g. older image ran **winetricks** before **Proton** initialized the bottle). **Remove the prefix and the corefonts stamp**, then rebuild/restart with a current image (inside the desktop or via `docker exec`):

```bash
rm -rf /config/wine-gameforge
rm -f /config/gameforge/.winetricks-corefonts.done
```

Use your real paths if you overrode **`GAMEFORGE_WINEPREFIX`** / **`GAMEFORGE_DIR`**.

---

## Environment variables (quick reference)

| Variable | Role |
|----------|------|
| `PUID` / `PGID` | LinuxServer user ids (default 1000 in [docker-compose.yml](../docker-compose.yml)). |
| `TZ` | IANA timezone for the container and Gameforge/Wine scripts (default **Dockerfile** `ENV`; override via compose `env_file` / runtime env). |
| `SELKIES_MANUAL_WIDTH` / `SELKIES_MANUAL_HEIGHT` / `MAX_RESOLUTION` | Selkies / X11 size (defaults in **Dockerfile**). |
| `GAMEFORGE_AUTOSTART` | `true` / `false` — installer autostart (default in [docker-compose.yml](../docker-compose.yml)). |
| `GAMEFORGE_DOWNLOAD_URL` | Installer URL (optional; default in **`gameforge-autostart.sh`**). |
| `GAMEFORGE_WINEPREFIX` | Wine prefix path (default `/config/wine-gameforge`). |
| `GAMEFORGE_DIR` | Cached installer + stamps (default `/config/gameforge`). |
| `GAMEFORGE_CLIENT_EXE_RELPATH` | Path to client exe inside prefix. |
| `WINETRICKS_COREFONTS` | `false` to skip one-time corefonts. |
| `PROTON_USE_WINED3D` | `1` for OpenGL installer in headless-ish setups (default **Dockerfile**). |
| `GAMEFORGE_CEF_CHROME_FLAGS` | `0` to disable extra Chromium flags for gfclient. |
| `GAMEFORGE_CLIENT_LOG` | Override client log path. |
| `GAMEFORGE_GAMEID` / `GAMEFORGE_STORE` | umu database hints. |
| `PROTONPATH` / `GAMEFORGE_PROTONPATH` | Pin Proton tree; `PROTONPATH` wins if both set. |

To override **`PUID`** / **`GAMEFORGE_AUTOSTART`** etc.: edit **`environment:`** in [docker-compose.yml](../docker-compose.yml), or add **`env_file`** (e.g. **`local.env`**) under **`services.desktop`** (see [Compose env_file order](https://docs.docker.com/compose/environment-variables/set-environment-variables/)). For **`TZ`**, resolution envs, etc., change compose, an env file, or the **Dockerfile** and rebuild. For another installer URL, set **`GAMEFORGE_DOWNLOAD_URL`** (compose / env / runtime) or edit **`gameforge-autostart.sh`**. For another registry/tag, edit **`services.desktop.image:`** (and **`build:`** if you build locally). Optional **LinuxServer Webtop** settings (e.g. **`CUSTOM_USER`**, **`PASSWORD`**) come from the [base image](https://docs.linuxserver.io/images/docker-webtop/) if you add them to compose or an env file; they are not set in the default [compose](../docker-compose.yml).
