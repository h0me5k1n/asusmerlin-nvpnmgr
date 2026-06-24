#!/usr/bin/env bash
# smoke-test.sh
#
# Validates vpnmgr.sh and provider modules: syntax, shellcheck, provider contract
# completeness, repo hygiene, and attribution.
#
# Usage:
#   ./scripts/smoke-test.sh
#   ./scripts/smoke-test.sh --offline   (alias — all tests are offline)
#
# Exit code: 0 = all tests passed, 1 = one or more failures.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pass()    { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}$1${NC}"; }

PASS=0
FAIL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

echo -e "\n${BOLD}Smoke Test — vpnmgr${NC}"
echo "Repo: ${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Section 1: Syntax + shellcheck on all shell scripts
#
# These are ash (POSIX sh) scripts. sh -n checks syntax; shellcheck
# is run with --shell=sh to match the actual target environment.
# ---------------------------------------------------------------------------
section "1. Syntax and static analysis"

SHELL_SCRIPTS=(vpnmgr.sh)

while IFS= read -r -d '' f; do
    SHELL_SCRIPTS+=("${f#${REPO_ROOT}/}")
done < <(find "${REPO_ROOT}/providers" -name '*.sh' -print0 2>/dev/null | sort -z)

SHELLCHECK_AVAILABLE=false
if command -v shellcheck &>/dev/null; then
    SHELLCHECK_AVAILABLE=true
fi

for script in "${SHELL_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        fail "${script} — file not found"
        continue
    fi

    if sh -n "$script" 2>/dev/null; then
        pass "${script} — sh -n"
    else
        fail "${script} — sh -n: $(sh -n "$script" 2>&1)"
        continue
    fi

    if [[ "$SHELLCHECK_AVAILABLE" == true ]]; then
        sc_out=$(shellcheck --shell=sh --severity=warning "$script" 2>&1) || true
        if [[ -z "$sc_out" ]]; then
            pass "${script} — shellcheck"
        else
            fail "${script} — shellcheck"
            echo "$sc_out" | sed 's/^/    /'
        fi
    fi
done

if [[ "$SHELLCHECK_AVAILABLE" == false ]]; then
    warn "shellcheck not found — skipping static analysis (install: apt install shellcheck)"
fi

# ---------------------------------------------------------------------------
# Section 2: Provider contract completeness
#
# The core dispatches to these 17 functions for every configured provider.
# Verify each non-template provider module implements all of them.
# ---------------------------------------------------------------------------
section "2. Provider contract"

REQUIRED_FUNCS=(
    version
    get_server
    get_ovpn
    get_comp
    get_hmac
    get_short_name
    write_certs
    get_country_names
    get_country_id
    get_city_count
    get_city_names
    get_city_id
    country_required
    city_required
    get_types
    get_server_load
    refresh_cache
)

if [[ ! -d "${REPO_ROOT}/providers" ]]; then
    warn "providers/ directory not found — skipping contract checks"
else
    provider_count=0
    while IFS= read -r -d '' pfile; do
        pname=$(basename "$pfile" .sh | sed 's/^provider_//')
        [[ "$pname" == "template" ]] && continue
        provider_count=$((provider_count + 1))
        for fn in "${REQUIRED_FUNCS[@]}"; do
            fqfn="provider_${pname}_${fn}"
            if grep -q "^${fqfn}(){" "$pfile" || grep -q "^${fqfn}() {" "$pfile"; then
                pass "${pname}: ${fn}()"
            else
                fail "${pname}: missing ${fqfn}()"
            fi
        done
    done < <(find "${REPO_ROOT}/providers" -name 'provider_*.sh' -print0 | sort -z)

    if [[ $provider_count -eq 0 ]]; then
        warn "No non-template provider modules found in providers/"
    fi
fi

# ---------------------------------------------------------------------------
# Section 3: Repo hygiene — no provider config files committed
# ---------------------------------------------------------------------------
section "3. Repo hygiene"

for pat in '*.ovpn' '*.zip' '*.p12' '*.pem'; do
    hits=$(git -C "${REPO_ROOT}" ls-files "$pat" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then
        pass "No ${pat} files committed"
    else
        fail "Committed ${pat} files found (must download at runtime, never commit):"
        echo "$hits" | sed 's/^/    /'
    fi
done

# ---------------------------------------------------------------------------
# Section 4: Core cleanliness — no inline provider API URLs in vpnmgr.sh
#
# Provider-specific API endpoints belong in provider modules, not the core.
# ---------------------------------------------------------------------------
section "4. Core script cleanliness"

for pat in 'api\.nordvpn\.com' 'nordcdn\.com' 'privateinternetaccess\.com' 'wevpn\.com'; do
    hits=$(grep -n "$pat" "${REPO_ROOT}/vpnmgr.sh" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then
        pass "vpnmgr.sh: no inline ${pat}"
    else
        fail "vpnmgr.sh: provider-specific URL found (should be in provider module):"
        echo "$hits" | sed 's/^/    /'
    fi
done

# ---------------------------------------------------------------------------
# Section 5: Attribution — SCRIPT_REPO points to h0me5k1n
# ---------------------------------------------------------------------------
section "5. Attribution"

if grep -q 'SCRIPT_REPO=.*h0me5k1n' "${REPO_ROOT}/vpnmgr.sh"; then
    repo_val=$(grep 'SCRIPT_REPO=' "${REPO_ROOT}/vpnmgr.sh" | head -1 | sed 's/.*="\(.*\)"/\1/')
    pass "SCRIPT_REPO → ${repo_val}"
else
    actual=$(grep 'SCRIPT_REPO=' "${REPO_ROOT}/vpnmgr.sh" | head -1 || echo "(not found)")
    fail "SCRIPT_REPO does not point to h0me5k1n — got: ${actual}"
fi

# ---------------------------------------------------------------------------
# Section 6: Provider status headers
# ---------------------------------------------------------------------------
section "6. Provider status headers"

if [[ -d "${REPO_ROOT}/providers" ]]; then
    while IFS= read -r -d '' pfile; do
        pname=$(basename "$pfile" .sh | sed 's/^provider_//')
        if grep -q '^# Status:' "$pfile"; then
            status=$(grep '^# Status:' "$pfile" | head -1 | sed 's/^# Status: *//')
            pass "${pname}: Status: ${status}"
        else
            fail "${pname}: missing '# Status:' header"
        fi
    done < <(find "${REPO_ROOT}/providers" -name 'provider_*.sh' -print0 | sort -z)
fi

# ---------------------------------------------------------------------------
# Section 7: .gitignore coverage
# ---------------------------------------------------------------------------
section "7. .gitignore coverage"

for pat in '*.ovpn' '*.zip' '*.p12' '*.pem'; do
    if grep -qF "$pat" "${REPO_ROOT}/.gitignore" 2>/dev/null; then
        pass ".gitignore: ${pat}"
    else
        fail ".gitignore missing ${pat} — provider config files could be accidentally committed"
    fi
done

# ---------------------------------------------------------------------------
# Section 8: WebUI files
# ---------------------------------------------------------------------------
section "8. WebUI files"

WEBUI_JS="${REPO_ROOT}/vpnmgr_www.js"

# No ES6+ in the JS file — router WebKit does not support ES6
for pat in '\blet ' '\bconst ' '=>' '`' '\bfetch('; do
    hits=$(grep -n "$pat" "$WEBUI_JS" || true)
    if [[ -z "$hits" ]]; then
        pass "vpnmgr_www.js: no ES6+ pattern (${pat})"
    else
        fail "vpnmgr_www.js: ES6+ pattern '${pat}' found (not safe on router WebKit):"
        echo "$hits" | sed 's/^/    /'
    fi
done

# TODO (Phase 5): JS syntax check via node
# TODO (Phase 5): jQuery uses \$j not \$ (noConflict — \$ clashes with Merlin's prototype.js)
# TODO (Phase 5): No hardcoded country arrays — must load dynamically from provider data files
# TODO (Phase 5): CSS syntax check via stylelint

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}─────────────────────────────────────────${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All ${TOTAL} tests passed.${NC}"
else
    echo -e "${RED}${BOLD}${FAIL} of ${TOTAL} tests failed.${NC}"
fi
echo -e "${BOLD}─────────────────────────────────────────${NC}"
echo ""

[[ $FAIL -eq 0 ]]
