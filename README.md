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

## Roadmap

Work progresses in phases. Completed phases are merged to `main`; in-progress work is on feature branches.

- [x] **Phase 1** — Fork merge: jackyaz's v2.3.2 merged back as the new baseline, WeVPN ZIP files removed
- [x] **Phase 2** — Modular provider architecture: all provider logic extracted to `providers/provider_<name>.sh`; CI smoke test added
- [ ] **Phase 3** — URL and branding sweep: remaining `jackyaz` references in WebUI files, banner/header update, integrity check
- [ ] **Phase 4** — WebUI adaptation: ES6 → ES5, dynamic country/city dropdowns from provider data files (not hardcoded JS arrays), provider selection per VPN client
- [ ] **Phase 5** — Full documentation: provider module authoring guide, contributing guide, updated CLI/WebUI screenshots
- [ ] **Tooling** — Claude Code agents/skills for scaffolding a new provider module and running provider smoke tests on a live router

## Development

### Installing from a branch

Replace `<branch>` with the branch name (e.g. `feat/phase4-webui`):

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/<branch>/vpnmgr.sh" -o "/jffs/scripts/vpnmgr" && chmod 0755 /jffs/scripts/vpnmgr && /jffs/scripts/vpnmgr install
```

To switch a running installation between the stable release and the `develop` branch:

```sh
vpnmgr switch stable    # pins to main
vpnmgr switch develop   # pins to develop branch
```

### Adding a provider

Copy `providers/provider_template.sh` to `providers/provider_<name>.sh` and implement all 17 required functions. The contract is documented in the template header. Run `bash scripts/smoke-test.sh` locally to verify contract completeness before opening a PR — CI enforces this on every push.

## Credits

- [@jackyaz](https://github.com/jackyaz) — author of the expanded vpnmgr (WebUI, multi-provider, self-update, scheduling). His 429 commits are the backbone of this codebase.
- [@h0me5k1n](https://github.com/h0me5k1n) — original nvpnmgr concept and current maintainer.

## Licence

GPL-3.0. See [LICENSE](LICENSE).

## Help and issues

Please open an issue on this repo, or post in the [Asuswrt-Merlin AddOns forum on SNBForums](https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=11).
