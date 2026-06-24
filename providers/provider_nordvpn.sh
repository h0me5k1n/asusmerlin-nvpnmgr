#!/bin/sh
# NordVPN provider module for vpnmgr
# Status: ACTIVE
#
# Depends on: jq, curl
# Cache file: $SCRIPT_DIR/nordvpn_countrydata  (JSON array from NordVPN API)

##########         Shellcheck directives     ##########
# shellcheck disable=SC2039
# shellcheck disable=SC3043
#######################################################

provider_nordvpn_version(){
	printf "v1.0.0\n"
}

# Map human-readable type names to NordVPN API group identifiers
_nordvpn_type_to_api(){
	case "$1" in
		Standard)   printf "legacy_standard" ;;
		Double)     printf "legacy_double_vpn" ;;
		P2P)        printf "legacy_p2p" ;;
		Obfuscated) printf "legacy_obfuscated" ;;
		*)          printf "legacy_standard" ;;
	esac
}

# Map protocol SHORT (UDP/TCP) to NordVPN technology identifier
_nordvpn_prot_to_api(){
	case "$1" in
		UDP) printf "openvpn_udp" ;;
		TCP) printf "openvpn_tcp" ;;
		*)   printf "openvpn_udp" ;;
	esac
}

# provider_nordvpn_get_server country_id country_name city_id city_name protocol vpn_type
# Prints the server hostname on stdout.
provider_nordvpn_get_server(){
	_nord_countryid="$1"
	_nord_cityid="$3"
	_nord_prot="$5"
	_nord_type="$6"

	_nord_api_type="$(_nordvpn_type_to_api "$_nord_type")"
	_nord_api_prot="$(_nordvpn_prot_to_api "$_nord_prot")"

	_nord_vjson=""

	if [ "$_nord_countryid" -eq 0 ] 2>/dev/null || [ -z "$_nord_countryid" ]; then
		# No country filter — worldwide
		_nord_vjson="$(_nordvpn_get_recommended "$_nord_api_type" "$_nord_api_prot" 0)"
	elif [ "$_nord_cityid" -eq 0 ] 2>/dev/null || [ -z "$_nord_cityid" ]; then
		# Country only
		_nord_vjson="$(_nordvpn_get_recommended "$_nord_api_type" "$_nord_api_prot" "$_nord_countryid")"
	else
		# City + country
		_nord_vjson="$(_nordvpn_get_city "$_nord_api_type" "$_nord_api_prot" "$_nord_countryid" "$_nord_cityid")"
		if [ -z "$_nord_vjson" ]; then
			Print_Output true "NordVPN: No server found for city, falling back to country" "$WARN"
			_nord_vjson="$(_nordvpn_get_recommended "$_nord_api_type" "$_nord_api_prot" "$_nord_countryid")"
		fi
		if [ -z "$_nord_vjson" ]; then
			Print_Output true "NordVPN: No server found for country, falling back to worldwide" "$WARN"
			_nord_vjson="$(_nordvpn_get_recommended "$_nord_api_type" "$_nord_api_prot" 0)"
		fi
	fi

	[ -z "$_nord_vjson" ] && Print_Output true "NordVPN: API returned no servers" "$ERR" && return 1

	_nord_hostname="$(printf '%s' "$_nord_vjson" | jq -r -e '.hostname // empty')"
	[ -z "$_nord_hostname" ] && Print_Output true "NordVPN: Could not determine hostname" "$ERR" && return 1

	_nord_load="$(printf '%s' "$_nord_vjson" | jq -r '.load // empty')"
	if [ -n "$_nord_load" ]; then
		printf '%s' "$_nord_load" > "$SCRIPT_DIR/nordvpn_load_${_nord_hostname%%.*}"
	fi

	printf '%s' "$_nord_hostname"
}

_nordvpn_get_recommended(){
	_nr_type="$1"
	_nr_prot="$2"
	_nr_cid="$3"
	_nr_url="https://api.nordvpn.com/v1/servers/recommendations?filters[servers_groups][identifier]=${_nr_type}&filters[servers_technologies][identifier]=${_nr_prot}"
	if [ "$_nr_cid" -ne 0 ] 2>/dev/null; then
		_nr_url="${_nr_url}&filters[country_id]=${_nr_cid}"
	fi
	_nr_url="${_nr_url}&limit=1"
	/usr/sbin/curl --globoff -fsL --retry 3 "$_nr_url" | jq -r -e '.[] // empty'
}

_nordvpn_get_city(){
	_nc_type="$1"
	_nc_prot="$2"
	_nc_cid="$3"
	_nc_cityid="$4"
	/usr/sbin/curl --globoff -fsL --retry 3 \
		"https://api.nordvpn.com/v1/servers/recommendations?filters[servers_groups][identifier]=${_nc_type}&filters[servers_technologies][identifier]=${_nc_prot}&filters[country_id]=${_nc_cid}&limit=2500" \
		| jq -r -e "[ .[] | select(.locations[].country.city.id==${_nc_cityid})][0] // empty"
}

# provider_nordvpn_get_ovpn hostname protocol vpn_type
# Downloads OVPN file from NordVPN CDN and prints contents to stdout.
provider_nordvpn_get_ovpn(){
	_gov_hostname="$1"
	_gov_prot="$2"
	_gov_prot_lc="$(printf '%s' "$_gov_prot" | tr 'A-Z' 'a-z')"
	/usr/sbin/curl -fsL --retry 3 \
		"https://downloads.nordcdn.com/configs/files/ovpn_${_gov_prot_lc}/servers/${_gov_hostname}.${_gov_prot_lc}.ovpn"
}

# provider_nordvpn_get_comp
provider_nordvpn_get_comp(){
	printf -- "-1"
}

# provider_nordvpn_get_hmac
provider_nordvpn_get_hmac(){
	printf "1"
}

# provider_nordvpn_get_short_name hostname addr
provider_nordvpn_get_short_name(){
	printf '%s' "$1" | cut -f1 -d'.' | tr 'a-z' 'A-Z'
}

# provider_nordvpn_write_certs vpn_no ovpn_detail
# Writes ca + static (tls-auth); removes crl, key, crt.
provider_nordvpn_write_certs(){
	_wc_no="$1"
	_wc_ovpn="$2"

	_wc_ca="$(printf '%s' "$_wc_ovpn" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_ca" ] && Print_Output true "NordVPN: Error determining CA certificate" "$ERR" && return 1

	_wc_static="$(printf '%s' "$_wc_ovpn" | awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_static" ] && Print_Output true "NordVPN: Error determining static (tls-auth) key" "$ERR" && return 1

	printf '%s\n' "$_wc_ca"     > /jffs/openvpn/vpn_crt_client"${_wc_no}"_ca
	printf '%s\n' "$_wc_static" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_static
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crl
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_key
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crt
}

# provider_nordvpn_get_country_names
# Reads cached country data JSON and prints country names, one per line.
provider_nordvpn_get_country_names(){
	_cdata="$SCRIPT_DIR/nordvpn_countrydata"
	if [ ! -f "$_cdata" ]; then
		Print_Output true "NordVPN: Country data cache missing — run refreshcacheddata" "$ERR"
		return 1
	fi
	jq -r -e '.[] | .name // empty' "$_cdata"
}

# provider_nordvpn_get_country_id country_name
provider_nordvpn_get_country_id(){
	_cdata="$SCRIPT_DIR/nordvpn_countrydata"
	jq -r -e ".[] | select(.name==\"$1\") | .id // empty" "$_cdata"
}

# provider_nordvpn_get_city_count country_name
provider_nordvpn_get_city_count(){
	_cdata="$SCRIPT_DIR/nordvpn_countrydata"
	jq -r -e ".[] | select(.name==\"$1\") | .cities | length // empty" "$_cdata"
}

# provider_nordvpn_get_city_names country_name
provider_nordvpn_get_city_names(){
	_cdata="$SCRIPT_DIR/nordvpn_countrydata"
	jq -r -e ".[] | select(.name==\"$1\") | .cities[] | .name // empty" "$_cdata"
}

# provider_nordvpn_get_city_id country_name city_name
provider_nordvpn_get_city_id(){
	_cdata="$SCRIPT_DIR/nordvpn_countrydata"
	jq -r -e ".[] | select(.name==\"$1\") | .cities[] | select(.name==\"$2\") | .id // empty" "$_cdata"
}

# provider_nordvpn_country_required
# Returns 1 — country selection is optional for NordVPN.
provider_nordvpn_country_required(){
	return 1
}

# provider_nordvpn_city_required
# Returns 1 — city selection is optional for NordVPN.
provider_nordvpn_city_required(){
	return 1
}

# provider_nordvpn_get_types
# Prints available VPN types, one per line.
provider_nordvpn_get_types(){
	printf "Standard\nDouble\nP2P\n"
}

# provider_nordvpn_get_server_load desc
# desc: nvram vpn_clientX_desc value ("NordVPN <hostname_short> <type> <proto>")
# Reads load written by get_server at selection time.
# NordVPN /server/stats/ API was deprecated; load is cached from recommendations response.
provider_nordvpn_get_server_load(){
	_sl_desc="$1"
	_sl_short="$(printf '%s' "$_sl_desc" | cut -f2 -d ' ' | tr 'A-Z' 'a-z')"
	_sl_cache="$SCRIPT_DIR/nordvpn_load_${_sl_short}"
	if [ -f "$_sl_cache" ]; then
		cat "$_sl_cache"
	else
		printf 'Unknown\n'
	fi
}

# provider_nordvpn_refresh_cache
# Downloads NordVPN country data, compares with cached copy, updates if changed.
provider_nordvpn_refresh_cache(){
	Print_Output true "NordVPN: Refreshing country data..."
	/usr/sbin/curl -fsL --retry 3 "https://api.nordvpn.com/v1/servers/countries" \
		| jq -r > /tmp/nordvpn_countrydata
	_rc_data="$(cat /tmp/nordvpn_countrydata)"
	if [ -z "$_rc_data" ]; then
		Print_Output true "NordVPN: Country data failed to download" "$ERR"
		rm -f /tmp/nordvpn_countrydata
		return 1
	fi
	if [ -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
		if ! diff -q /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata" >/dev/null 2>&1; then
			mv /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata"
			Print_Output true "NordVPN: Country data updated" "$PASS"
			Create_Symlinks
		else
			rm -f /tmp/nordvpn_countrydata
			Print_Output true "NordVPN: Country data unchanged" "$WARN"
		fi
	else
		mv /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata"
		Create_Symlinks
		Print_Output true "NordVPN: Country data downloaded (first run)" "$PASS"
	fi
}

# provider_nordvpn_needs_cache
# Returns 0 (needs refresh) if cache file is missing, 1 if present.
provider_nordvpn_needs_cache(){
	if [ ! -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
		return 0
	fi
	return 1
}
