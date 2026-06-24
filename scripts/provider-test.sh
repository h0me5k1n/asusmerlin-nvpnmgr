#!/usr/bin/env bash
# provider-test.sh
#
# Exercises a vpnmgr provider module locally against its live API.
# Requires: curl, jq
#
# Usage:
#   bash scripts/provider-test.sh <provider>
#   bash scripts/provider-test.sh nordvpn

set -euo pipefail

# ---------------------------------------------------------------------------
# Output helpers
# N_PASS/N_FAIL/N_SKIP are test counters.
# PASS/WARN/ERR/CRIT/BOLD/CLEARFORMAT are colour codes expected by providers.
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD_FMT='\033[1m'
NC='\033[0m'

N_PASS=0; N_FAIL=0; N_SKIP=0

_pass()  { echo -e "  ${GREEN}✓${NC}  $1"; N_PASS=$((N_PASS + 1)); }
_fail()  { echo -e "  ${RED}✗${NC}  $1"; N_FAIL=$((N_FAIL + 1)); }
_skip()  { echo -e "  ${YELLOW}!${NC}  $1"; N_SKIP=$((N_SKIP + 1)); }
_warn()  { echo -e "  ${YELLOW}WARNING:${NC} $1"; }
_info()  { echo -e "     $1"; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    echo "Usage: bash scripts/provider-test.sh <provider>"
    echo "       e.g.  bash scripts/provider-test.sh nordvpn"
    exit 1
fi

PROVIDER="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVIDER_SCRIPT="$REPO_ROOT/providers/provider_${PROVIDER}.sh"

if [ ! -f "$PROVIDER_SCRIPT" ]; then
    echo -e "${RED}Error:${NC} provider file not found: $PROVIDER_SCRIPT"
    echo "Available providers:"
    ls "$REPO_ROOT/providers/provider_"*.sh 2>/dev/null \
        | sed 's|.*/provider_||; s|\.sh||' | grep -v template | sed 's/^/  /'
    exit 1
fi

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} '$cmd' not found — install it before running this script"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Provider status
# ---------------------------------------------------------------------------
STATUS=$(grep '^# Status:' "$PROVIDER_SCRIPT" | head -1 | sed 's/^# Status: //' | awk '{print $1}')

echo ""
echo -e "${BOLD_FMT}[provider-test]${NC} ${PROVIDER} provider — local API test"
echo ""

case "$STATUS" in
    TEMPLATE)
        echo -e "${RED}Error:${NC} '$PROVIDER' is the template — not a real provider"
        exit 1
        ;;
    DEPRECATED)
        _warn "Provider is DEPRECATED — the service is offline"
        _warn "Network tests will be skipped; only static function tests will run"
        echo ""
        NETWORK_TESTS=false
        ;;
    UNMAINTAINED)
        _warn "Provider is UNMAINTAINED — API tests may fail if the service has changed"
        echo ""
        NETWORK_TESTS=true
        ;;
    *)
        NETWORK_TESTS=true
        ;;
esac

# ---------------------------------------------------------------------------
# Environment stubs
# These satisfy router-specific dependencies that don't exist locally.
# PASS/WARN/ERR/CRIT/BOLD/CLEARFORMAT match the names vpnmgr.sh exports
# so providers that call Print_Output get the right colour codes.
# ---------------------------------------------------------------------------
SCRIPT_DIR="/tmp/vpnmgr_test_$$"
OVPN_ARCHIVE_DIR="$SCRIPT_DIR/ovpn"
SCRIPT_REPO="https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/main"

PASS="\\e[32m"
WARN="\\e[33m"
ERR="\\e[31m"
CRIT="\\e[31m"
BOLD="\\e[1m"
CLEARFORMAT="\\e[0m"

Print_Output() { printf '%b%s%b\n' "${3:-}" "$2" "$CLEARFORMAT" >&2; }
Download_File() { curl -fsL --retry 3 "$1" -o "$2"; }
Create_Symlinks() { :; }

mkdir -p "$SCRIPT_DIR" "$OVPN_ARCHIVE_DIR"
trap 'rm -rf "$SCRIPT_DIR"' EXIT

# ---------------------------------------------------------------------------
# Source the provider, patching /usr/sbin/curl → curl for local dev machines
# (on the router /usr/sbin/curl exists; locally curl is in PATH)
# ---------------------------------------------------------------------------
PATCHED_SCRIPT="$SCRIPT_DIR/provider_${PROVIDER}.sh"
sed 's|/usr/sbin/curl|curl --globoff|g' "$PROVIDER_SCRIPT" > "$PATCHED_SCRIPT"
# shellcheck source=/dev/null
. "$PATCHED_SCRIPT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
call() {
    local fn="provider_${PROVIDER}_${1}"
    shift
    "$fn" "$@"
}

# ---------------------------------------------------------------------------
# Static tests (always run)
# ---------------------------------------------------------------------------
echo -e "${BOLD_FMT}Static functions${NC}"

ver=$(call version 2>/dev/null) && _pass "version → $ver" || _fail "version"
comp=$(call get_comp 2>/dev/null) && _pass "get_comp → $comp" || _fail "get_comp"
hmac=$(call get_hmac 2>/dev/null) && _pass "get_hmac → $hmac" || _fail "get_hmac"

types_out=$(call get_types 2>/dev/null) && {
    types_fmt=$(printf '%s' "$types_out" | tr '\n' ',' | sed 's/,$//')
    _pass "get_types → $types_fmt"
} || _fail "get_types"

# country_required and city_required return 0 = required, 1 = optional — both are valid
if call country_required 2>/dev/null; then
    _pass "country_required → required"
else
    _pass "country_required → optional"
fi

if call city_required 2>/dev/null; then
    _pass "city_required → required"
else
    _pass "city_required → optional"
fi

echo ""

# ---------------------------------------------------------------------------
# Network tests
# ---------------------------------------------------------------------------
if [ "$NETWORK_TESTS" = "false" ]; then
    for fn in refresh_cache get_country_names get_country_id get_city_count \
              get_city_names get_server get_server_load get_ovpn "write_certs dry run"; do
        _skip "$fn — skipped (deprecated — service offline)"
    done
else
    echo -e "${BOLD_FMT}Network functions${NC}"

    # refresh_cache
    server=""
    ovpn_content=""
    start=$(date +%s%3N)
    if call refresh_cache 2>/dev/null; then
        end=$(date +%s%3N); elapsed=$(( end - start ))
        cache_file="$SCRIPT_DIR/${PROVIDER}_countrydata"
        if [ -f "$cache_file" ]; then
            country_count=$(jq 'length' "$cache_file" 2>/dev/null || echo "?")
            _pass "refresh_cache [${elapsed}ms] — ${country_count} countries cached"
        else
            _pass "refresh_cache [${elapsed}ms]"
        fi
    else
        _fail "refresh_cache — API call failed"
    fi

    # get_country_names
    names=$(call get_country_names 2>/dev/null) && {
        total=$(printf '%s\n' "$names" | wc -l | tr -d ' ')
        preview=$(printf '%s\n' "$names" | head -5 | tr '\n' ',' | sed 's/,$//')
        _pass "get_country_names — $total countries (${preview}...)"
    } || _fail "get_country_names"

    # get_country_id for United Kingdom
    country_name="United Kingdom"
    country_id=""
    country_id=$(call get_country_id "$country_name" 2>/dev/null) && {
        _pass "get_country_id '$country_name' → $country_id"
    } || {
        _fail "get_country_id '$country_name' — returned empty"
        country_id="0"
    }

    # get_city_count
    city_count=$(call get_city_count "$country_name" 2>/dev/null) && {
        _pass "get_city_count '$country_name' → $city_count cities"
    } || _fail "get_city_count '$country_name'"

    # get_city_names
    city_names=$(call get_city_names "$country_name" 2>/dev/null) && {
        cities_fmt=$(printf '%s\n' "$city_names" | tr '\n' ',' | sed 's/,$//')
        _pass "get_city_names '$country_name' → $cities_fmt"
    } || _fail "get_city_names '$country_name'"

    # get_server — country only, no city, UDP, Standard
    start=$(date +%s%3N)
    server=$(call get_server "$country_id" "$country_name" "0" "" "UDP" "Standard" 2>/dev/null) && {
        end=$(date +%s%3N); elapsed=$(( end - start ))
        _pass "get_server [${elapsed}ms] → $server"
    } || {
        _fail "get_server — returned empty"
        server=""
    }

    # get_server_load
    # The function expects the nvram vpn_clientX_desc format: "<tag> <hostname_short>"
    # It cuts field 2 (space-delimited) then appends .nordvpn.com to build the stats URL.
    if [ -n "$server" ]; then
        server_short="${server%%.*}"
        load=$(call get_server_load "NordVPN $server_short" 2>/dev/null) && {
            _pass "get_server_load '$server' → ${load}%"
        } || _fail "get_server_load '$server' — NordVPN /server/stats/ API returns 403 (deprecated by NordVPN; provider needs updating)"
    else
        _skip "get_server_load — skipped (no server from get_server)"
    fi

    # get_ovpn
    if [ -n "$server" ]; then
        start=$(date +%s%3N)
        ovpn_content=$(call get_ovpn "$server" "UDP" "Standard" 2>/dev/null) && {
            end=$(date +%s%3N); elapsed=$(( end - start ))
            byte_count=${#ovpn_content}
            _pass "get_ovpn [${elapsed}ms] — ${byte_count} bytes"
            _info "$(printf '%s\n' "$ovpn_content" | head -8 | sed 's/^/     /')"
        } || {
            _fail "get_ovpn — returned empty (CDN unreachable or server not found)"
            ovpn_content=""
        }
    else
        _skip "get_ovpn — skipped (no server from get_server)"
        ovpn_content=""
    fi

    # write_certs dry run
    echo ""
    echo -e "${BOLD_FMT}write_certs (dry run)${NC}"
    if [ -n "$ovpn_content" ]; then
        _ca=$(printf '%s' "$ovpn_content" \
            | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d')
        _static=$(printf '%s' "$ovpn_content" \
            | awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag' | sed '/^#/ d')

        if [ -n "$_ca" ] && [ -n "$_static" ]; then
            _pass "CA and tls-auth blocks extractable from OVPN"
            _info "CA first line:       $(printf '%s\n' "$_ca"     | head -1)"
            _info "CA last line:        $(printf '%s\n' "$_ca"     | tail -1)"
            _info "tls-auth first line: $(printf '%s\n' "$_static" | head -1)"
            _info "Would write: /jffs/openvpn/vpn_crt_client1_ca"
            _info "             /jffs/openvpn/vpn_crt_client1_static"
        elif [ -z "$_ca" ]; then
            _fail "write_certs dry run — <ca> block missing from OVPN"
        else
            _fail "write_certs dry run — <tls-auth> block missing from OVPN"
        fi
    else
        _skip "write_certs dry run — skipped (no OVPN content from get_ovpn)"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((N_PASS + N_FAIL + N_SKIP))
echo ""
echo -e "${BOLD_FMT}─────────────────────────────────────────${NC}"
if [ $N_FAIL -eq 0 ]; then
    echo -e "${GREEN}${BOLD_FMT}${N_PASS} passed${NC}, ${N_SKIP} skipped (${TOTAL} total)"
else
    echo -e "${RED}${BOLD_FMT}${N_FAIL} failed${NC}, ${N_PASS} passed, ${N_SKIP} skipped (${TOTAL} total)"
fi
echo -e "${BOLD_FMT}─────────────────────────────────────────${NC}"
echo ""

[ $N_FAIL -eq 0 ]
