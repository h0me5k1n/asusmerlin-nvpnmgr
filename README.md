# vpnmgr

![CI](https://github.com/h0me5k1n/asusmerlin-nvpnmgr/actions/workflows/ci.yml/badge.svg)

VPN client manager for AsusWRT-Merlin routers. Manages up to five OpenVPN clients — server selection, scheduled refresh, OVPN config application, and a router WebUI tab.

## Supported firmware

Asuswrt-Merlin 384.15 / 384.13_4 or Fork 43E5 or later — [asuswrt-merlin.ng](https://asuswrt.lostrealm.ca/)

## Installation

From an SSH session on the router:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/main/vpnmgr.sh" -o "/jffs/scripts/vpnmgr" && chmod 0755 /jffs/scripts/vpnmgr && /jffs/scripts/vpnmgr install
```

## Usage

vpnmgr adds a tab to the VPN section in the router WebUI.

To launch the interactive CLI menu over SSH:

```sh
vpnmgr
```

If that doesn't work (script not yet on `$PATH`):

```sh
/jffs/scripts/vpnmgr
```

## Provider status

| Provider | Status |
|----------|--------|
| **NordVPN** | Active — maintained and tested |
| **Private Internet Access (PIA)** | Untested — rewritten to use PIA JSON API; needs verification on a live account |
| **WeVPN** | Deprecated — WeVPN is no longer operational |

## Repository layout

```
vpnmgr/
├── vpnmgr.sh                   # Core script — CLI, scheduler, VPN client control, self-update
├── vpnmgr_www.asp              # WebUI page (AsusWRT-Merlin Addons API)
├── vpnmgr_www.js               # WebUI logic
├── vpnmgr_www.css              # WebUI styles
├── www/                        # Bundled web assets (served from /ext/vpnmgr/www/)
│   ├── jquery.js               # jQuery v3.5.1
│   └── detect.js               # LAN detection helper
├── providers/                  # Provider sub-scripts
│   ├── provider_nordvpn.sh     # NordVPN — active
│   ├── provider_pia.sh         # PIA — unmaintained
│   ├── provider_wevpn.sh       # WeVPN — deprecated
│   └── provider_template.sh   # Template for new providers
├── scripts/
│   ├── smoke-test.sh           # Local CI smoke test
│   └── provider-test.sh        # Live API test harness for provider modules
└── .github/workflows/ci.yml    # GitHub Actions — runs smoke-test on every PR
```

## Development

### Installing from a branch

Replace `<branch>` with the branch name:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/<branch>/vpnmgr.sh" -o "/jffs/scripts/vpnmgr" && chmod 0755 /jffs/scripts/vpnmgr && /jffs/scripts/vpnmgr install
```

To switch a running installation between the stable release and the `develop` branch:

```sh
vpnmgr switch stable    # pins to main
vpnmgr switch develop   # pins to develop branch
```

### Testing a provider locally

Before deploying to a router, verify a provider's API integration works from your local machine (requires `curl` and `jq`):

```sh
bash scripts/provider-test.sh nordvpn
```

This exercises the live NordVPN API — country/city lookups, server recommendations, OVPN config download, and cert extraction — without touching any router state. `write_certs` is validated as a dry run: the CA and tls-auth blocks are extracted from the downloaded OVPN and verified, but nothing is written to the filesystem.

Providers marked `DEPRECATED` in their `# Status:` header skip network tests automatically.

### Adding a provider

Copy `providers/provider_template.sh` to `providers/provider_<name>.sh` and implement all 17 required functions. The contract is documented in the template header.

Run `bash scripts/smoke-test.sh` locally before opening a PR — CI enforces this on every push.

### Shell compatibility

All `.sh` files must be **busybox ash compatible**. No bash arrays, no `[[ ]]`, no `let`, no `declare`, no process substitution. The router does not have bash.

## Roadmap

- [x] **Phase 1** — Fork merge: jackyaz's v2.3.2 merged as the new baseline; WeVPN ZIP files removed
- [x] **Phase 2** — Modular providers: all provider logic extracted to `providers/`; CI smoke test added
- [x] **Phase 3** — Branding sweep: URLs, integrity check, and banner updated to h0me5k1n
- [x] **Phase 4** — Web assets: `jquery.js` and `detect.js` bundled in `www/`; `jackyaz/shared-jy` dependency removed
- [ ] **Phase 5** — WebUI modernisation: ES6 → ES5 for router compatibility; dynamic dropdowns from provider data
- [ ] **Phase 6** — Documentation: provider authoring guide, contributing guide, CLI/WebUI screenshots

## Project history

1. **[h0me5k1n/asusmerlin-nvpnmgr](https://github.com/h0me5k1n/asusmerlin-nvpnmgr)** — the original project, NordVPN-only CLI.

2. **[jackyaz/vpnmgr](https://github.com/jackyaz/vpnmgr)** — [@jackyaz](https://github.com/jackyaz) forked and massively expanded it across 429 commits: full WebUI, multi-provider support, scheduled refresh, self-update. Now archived. His work is the backbone of this codebase and is preserved in full in the commit history.

3. **This repo** — jackyaz's fork merged back as the new baseline, revived and maintained by h0me5k1n.

## Credits

- [@jackyaz](https://github.com/jackyaz) — author of the expanded vpnmgr. His 429 commits are the foundation of this codebase.
- [@h0me5k1n](https://github.com/h0me5k1n) — original concept and current maintainer.

## Licence

GPL-3.0 — see [LICENSE](LICENSE).

## Help and issues

Open an issue on this repo, or post in the [Asuswrt-Merlin AddOns forum on SNBForums](https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=11).
