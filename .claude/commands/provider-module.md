# Skill: Provider Module Development

## Purpose

This skill covers implementing and testing VPN provider sub-scripts in the `providers/` directory. Each provider is a self-contained POSIX sh script (busybox ash compatible) that implements a 17-function contract, allowing `vpnmgr.sh` to support any VPN provider without modification.

Read `CLAUDE.md` first for project-wide context.

## Before you start

Run the smoke test and the local provider test for the provider you are editing to establish a baseline:

```sh
bash scripts/smoke-test.sh
bash scripts/provider-test.sh <provider>
```

Both must pass before and after your changes.

## Provider status

Every provider file has a `# Status:` header on line 3. The status MUST be set correctly at all times.

| Status | Meaning |
|--------|---------|
| `ACTIVE` | Maintained and verified working end-to-end on a real router with a live account |
| `UNTESTED` | Implementation complete but not yet verified on a real router/account |
| `UNMAINTAINED` | Was functional; no longer actively maintained — API tests still run |
| `DEPRECATED` | Provider service is offline; only static tests run in provider-test.sh |
| `TEMPLATE` | Not a real provider; provider-test.sh exits immediately |

**Rule: any change to a provider resets its status to `UNTESTED` until the change has been tested end-to-end with a live account on a real router.**

## Provider contract — 17 required functions

All function names follow the pattern `provider_<name>_<action>` where `<name>` matches the filename stem (e.g. `provider_nordvpn.sh` → `provider_nordvpn_*`). The smoke test verifies all 17 are present.

```sh
# Version string for this module
provider_<name>_version()

# Recommended server for the given parameters.
# Arguments: country_id country_name city_id city_name protocol vpn_type
# Prints the server identifier (hostname or region id) to stdout.
provider_<name>_get_server()

# OVPN configuration for the given server.
# Arguments: server_id protocol vpn_type
# Prints the complete OVPN content to stdout. NEVER write files directly.
provider_<name>_get_ovpn()

# OpenVPN compression setting ("adaptive", "no", "-1" for OVPN-file default)
provider_<name>_get_comp()

# TLS auth key direction (0, 1, or "" if tls-auth not used)
provider_<name>_get_hmac()

# Short human-readable label for the server (used in nvram vpn_clientX_desc)
# Arguments: server_id addr
provider_<name>_get_short_name()

# Write cert files to /jffs/openvpn/vpn_crt_client<no>_*
# Arguments: vpn_no ovpn_content
provider_<name>_write_certs()

# Newline-separated list of country display names, sorted.
provider_<name>_get_country_names()

# Country identifier for the given display name.
# Arguments: country_name
# Returns 0 if no numeric ID exists (PIA uses ISO codes; NordVPN uses integers).
provider_<name>_get_country_id()

# Number of available cities/regions for the given country.
# Arguments: country_name
provider_<name>_get_city_count()

# Newline-separated list of city/region names for the given country, sorted.
# Arguments: country_name
provider_<name>_get_city_names()

# City/region identifier for the given country+city name.
# Arguments: country_name city_name
provider_<name>_get_city_id()

# Returns 0 if country selection is required, 1 if optional.
provider_<name>_country_required()

# Returns 0 if city selection is required, 1 if optional.
provider_<name>_city_required()

# Newline-separated list of supported VPN types (e.g. Standard, Double, P2P)
provider_<name>_get_types()

# Current load for the given server. Prints a number or ""; never fails.
# Arguments: vpn_client_desc (nvram vpn_clientX_desc value)
provider_<name>_get_server_load()

# Download and cache server/country data. Called by the core on schedule.
provider_<name>_refresh_cache()
```

## Shell compatibility — mandatory

All provider code must run on busybox ash. Violations will fail `sh -n` or shellcheck in CI.

| Forbidden | Use instead |
|-----------|-------------|
| `[[ ]]` | `[ ]` |
| `local var` | just `_prefixed_var` (use a unique prefix to avoid collisions) |
| `let x=1` | `x=$((x + 1))` |
| `declare` / `typeset` | plain assignment |
| `${var,,}` / `${var^^}` | `printf '%s' "$var" \| tr 'A-Z' 'a-z'` |
| `$( < file )` | `$(cat file)` |
| Bash arrays | none — use newline-delimited strings with `while IFS= read -r` |
| Process substitution `<()` | temp files in `/tmp/` |

## Dependencies

Providers may use: `curl` (`/usr/sbin/curl` on the router), `jq`, `awk`, `sed`, `grep`, `sort`, `head`, `tail`, `cut`, `tr`, `cat`.

`jq` is a hard requirement — all providers use it for JSON parsing. It must be present on the development machine and on the router (install via Entware: `opkg install jq`). This is a project-level constraint, not provider-level. Do not use Python, node, or `7za` — these add further Entware dependencies that users may not have.

## curl on the router

Always call curl as `/usr/sbin/curl` (the router's curl binary, not Entware's). URLs containing `[` or `]` (common in API query strings) must have them written literally in the script — the router's curl does not glob them. This differs from Linux where you need `--globoff`; the local test harness (`provider-test.sh`) patches `/usr/sbin/curl → curl --globoff` automatically.

```sh
# Correct — works on router and is patched automatically for local testing
/usr/sbin/curl -fsL --retry 3 \
    "https://api.example.com/v1/servers?filters[country_id]=${_cid}&limit=1"
```

## Cache files

Use `$SCRIPT_DIR` (set by the core to `/jffs/addons/vpnmgr.d`) for persistent cache files. Use `/tmp/` for working files (clean up on failure). Never commit cache files — the `.gitignore` already excludes `*.ovpn`, `*.zip`, `*.p12`, `*.pem`.

Naming convention: `$SCRIPT_DIR/<provider>_<purpose>` — e.g. `pia_serverdata`, `nordvpn_countrydata`.

## `get_server` → `get_server_load` load caching

If your provider's server API returns a `load` field alongside the server identifier, cache it at `get_server` time:

```sh
_load="$(printf '%s' "$_vjson" | jq -r '.load // empty')"
[ -n "$_load" ] && printf '%s' "$_load" > "$SCRIPT_DIR/<provider>_load_${_hostname%%.*}"
```

Then `get_server_load` reads the cached file rather than making a separate API call (which may not exist or may be deprecated).

## `get_ovpn` — building configs dynamically vs downloading

Two patterns are used by existing providers:

**Download at connect time (NordVPN)**: The provider downloads a pre-built OVPN file from a CDN for the specific server. Simple, but depends on CDN availability.

**Build dynamically (PIA)**: The provider constructs the OVPN config in `get_ovpn` using a template with the server hostname and an embedded CA cert (identical for all servers). The CRL is downloaded and cached separately during `refresh_cache`. This removes the need to download per-server files at connect time.

## `write_certs` — what to write

Write only what is actually in the OVPN content:

```sh
provider_<name>_write_certs(){
    _wc_no="$1"
    _wc_ovpn="$2"

    _ca="$(printf '%s' "$_wc_ovpn" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag')"
    [ -z "$_ca" ] && Print_Output true "<name>: CA missing from OVPN" "$ERR" && return 1
    printf '%s\n' "$_ca" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_ca

    # tls-auth (NordVPN)
    _static="$(printf '%s' "$_wc_ovpn" | awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag')"
    [ -n "$_static" ] && printf '%s\n' "$_static" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_static \
                      || rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_static

    # crl-verify (PIA)
    _crl="$(printf '%s' "$_wc_ovpn" | awk '/<crl-verify>/{flag=1;next}/<\/crl-verify>/{flag=0}flag')"
    [ -n "$_crl" ] && printf '%s\n' "$_crl" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_crl \
                   || rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crl

    rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_key
    rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crt
}
```

## Testing a provider locally

`scripts/provider-test.sh` exercises all 17 contract functions against the live API without a router. Run it before opening a PR:

```sh
bash scripts/provider-test.sh nordvpn
bash scripts/provider-test.sh pia
```

The test harness:
- Stubs `Print_Output`, `Create_Symlinks`
- Patches `/usr/sbin/curl → curl --globoff` (Linux curl glob issue with bracket URLs)
- Runs `refresh_cache`, then all metadata functions, then `get_server` → `get_server_load` → `get_ovpn` → `write_certs` dry run

`UNTESTED` and `UNMAINTAINED` providers run all tests with a warning banner. `DEPRECATED` providers skip network tests. `TEMPLATE` exits immediately.

## Adding a new provider — checklist

1. Copy `providers/provider_template.sh` to `providers/provider_<name>.sh`
2. Set `# Status: UNTESTED` on line 3
3. Implement all 17 functions
4. Bump `SCRIPT_VERSION` in `vpnmgr.sh` (CI will reject the PR if you don't — see core-script skill for semver guidance)
5. Run `sh -n providers/provider_<name>.sh` — must be clean
6. Run `bash scripts/smoke-test.sh` — must stay at the current pass count
7. Run `bash scripts/provider-test.sh <name>` — all network functions must pass
8. Open a PR — CI enforces the smoke test and version bump check on every push
9. Once tested end-to-end on a real router with a live account, update `# Status: ACTIVE`

## Updating an existing provider

Any change to a provider — API endpoint, config format, function logic — MUST:
- Reset its `# Status:` to `UNTESTED` until verified on a real router with a live account. This applies even to small changes like adding a flag to a curl call.
- Bump `SCRIPT_VERSION` in `vpnmgr.sh` — CI will reject the PR otherwise.

## Reference implementations

Check `# Status:` on line 3 of each file in `providers/` — that is always the source of truth.
Do not rely on any listing in docs.

Read the existing providers to understand the two implementation patterns:
- **`provider_nordvpn.sh`** — JSON API + CDN OVPN download; load cached from recommendations response
- **`provider_pia.sh`** — JSON API + dynamically built OVPN with embedded CA cert + downloaded CRL
