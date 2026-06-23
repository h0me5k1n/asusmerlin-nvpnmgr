# vpnmgr

![CI](https://github.com/h0me5k1n/asusmerlin-nvpnmgr/actions/workflows/ci.yml/badge.svg)

VPN client manager for AsusWRT-Merlin routers.

## Project history

This project has a three-chapter history:

1. **[h0me5k1n/asusmerlin-nvpnmgr](https://github.com/h0me5k1n/asusmerlin-nvpnmgr)** — the original repo, created by [@h0me5k1n](https://github.com/h0me5k1n). NordVPN-only, CLI menu, basic scheduled refresh.

2. **[jackyaz/vpnmgr](https://github.com/jackyaz/vpnmgr)** — [@jackyaz](https://github.com/jackyaz) forked the project and massively expanded it across 429 commits: full WebUI via the AsusWRT-Merlin Addons API, multi-provider support (NordVPN, Private Internet Access, WeVPN), scheduled auto-refresh, self-update mechanism, and significant code quality improvements. His work is the backbone of everything here and is preserved in full in the commit history.

3. **This repo (h0me5k1n/asusmerlin-nvpnmgr, being renamed to vpnmgr)** — jackyaz's fork has been merged back as the new baseline. The project is revived and actively maintained by h0me5k1n. jackyaz's contributions are credited throughout.

## Current state

This is the post-merge baseline — jackyaz's v2.3.2 code with the WeVPN provider ZIP files removed (configs are downloaded at runtime, never committed). The codebase is being restructured to use a modular provider architecture.

**Provider status:**
- **NordVPN** — actively maintained
- **Private Internet Access (PIA)** — present but unmaintained (extracted from jackyaz's work)
- **WeVPN** — deprecated (WeVPN is no longer operational)

## Supported firmware

Merlin 384.15/384.13_4 or Fork 43E5 (or later) — [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation

Using your preferred SSH client/terminal:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/main/vpnmgr.sh" -o "/jffs/scripts/vpnmgr" && chmod 0755 /jffs/scripts/vpnmgr && /jffs/scripts/vpnmgr install
```

> **Note:** This repo is being renamed from `asusmerlin-nvpnmgr` to `vpnmgr` on GitHub. The installation URL will update accordingly — GitHub will redirect the old URL automatically.

## Usage

vpnmgr adds a tab to the VPN menu in the router WebUI.

To launch the CLI menu over SSH:

```sh
vpnmgr
```

If that doesn't work:

```sh
/jffs/scripts/vpnmgr
```

## Screenshots

![WebUI](https://puu.sh/HevUo/0600bbea5c.png)

![CLI UI](https://puu.sh/HevPC/4f5ddfc3d6.png)

## Credits

- [@jackyaz](https://github.com/jackyaz) — author of the expanded vpnmgr (WebUI, multi-provider, self-update, scheduling). His 429 commits are the backbone of this codebase.
- [@h0me5k1n](https://github.com/h0me5k1n) — original nvpnmgr concept and current maintainer.

## Licence

GPL-3.0. See [LICENSE](LICENSE).

## Help and issues

Please open an issue on this repo, or post in the [Asuswrt-Merlin AddOns forum on SNBForums](https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=11).
