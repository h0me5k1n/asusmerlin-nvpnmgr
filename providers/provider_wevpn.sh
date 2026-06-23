#!/bin/sh
# WeVPN provider module for vpnmgr
# Status: DEPRECATED — WeVPN is no longer operational
#
# This module is kept for historical reference only. All network operations
# will fail or print a deprecation notice. Do not use for new configurations.

##########         Shellcheck directives     ##########
# shellcheck disable=SC2039
# shellcheck disable=SC3043
#######################################################

_WEVPN_DEPRECATED_MSG="WeVPN is no longer operational. This provider is deprecated."

provider_wevpn_version(){
	printf "v1.0.0\n"
}

# Internal country code mappings for WeVPN
_wevpn_sed_country_codes_destructive(){
	sed 's/ /_/g;s/^AU_.*/Australia/I;s/^CA_.*/Canada/I;s/^DE_.*/Germany/I;s/^UAE_.*/United Arab Emirates/I;s/^UK_.*/United Kingdom/I;s/^US_.*/United States/I;
s/^AE_.*/United Arab Emirates/I;s/^GB_.*/United Kingdom/I;s/^AT_.*/Austria/I;s/^BE_.*/Belgium/I;s/^BG_.*/Bulgaria/I;s/^BR_.*/Brazil/I;
s/^CH_.*/Switzerland/I;s/^CZ_.*/Czech Republic/I;s/^DK_.*/Denmark/I;s/^ES_.*/Spain/I;s/^FR_.*/France/I;s/^HK_.*/Hong Kong/I;s/^HU_.*/Hungary/I;
s/^IE_.*/Ireland/I;s/^IL_.*/Israel/I;s/^IN_.*/India/I;s/^IT_.*/Italy/I;s/^JP_.*/Japan/I;s/^MX_.*/Mexico/I;s/^NL_.*/Netherlands/I;s/^NO_.*/Norway/I;s/^NZ_.*/New Zealand/I;
s/^PL_.*/Poland/I;s/^RO_.*/Romania/I;s/^RS_.*/Serbia/I;s/^SE_.*/Sweden/I;s/^SG_.*/Singapore/I;s/^ZA_.*/South Africa/I;s/_/ /g;'
}

_wevpn_sed_country_codes(){
	sed 's/ /_/g;s/^AU_/Australia/I;s/^CA_/Canada/I;s/^DE_/Germany/I;s/^UAE_/United Arab Emirates/I;s/^UK_/United Kingdom/I;s/^US_/United States/I;
s/^AE_/United Arab Emirates/I;s/^GB_/United Kingdom/I;s/^AT_/Austria/I;s/^BE_/Belgium/I;s/^BG_/Bulgaria/I;s/^BR_/Brazil/I;
s/^CH_/Switzerland/I;s/^CZ_/Czech Republic/I;s/^DK_/Denmark/I;s/^ES_/Spain/I;s/^FR_/France/I;s/^HK_/Hong Kong/I;s/^HU_/Hungary/I;
s/^IE_/Ireland/I;s/^IL_/Israel/I;s/^IN_/India/I;s/^IT_/Italy/I;s/^JP_/Japan/I;s/^MX_/Mexico/I;s/^NL_/Netherlands/I;s/^NO_/Norway/I;s/^NZ_/New Zealand/I;
s/^PL_/Poland/I;s/^RO_/Romania/I;s/^RS_/Serbia/I;s/^SE_/Sweden/I;s/^SG_/Singapore/I;s/^ZA_/South Africa/I;s/_/ /g;'
}

_wevpn_sed_reverse_country_codes(){
	sed 's/Australia/AU/;s/Canada/CA/;s/Germany/DE/;s/United States/US/;s/United Arab Emirates/AE/;s/United Kingdom/GB/;
s/Austria/AT/;s/Belgium/BE/;s/Bulgaria/BG/;s/Brazil/BR/;s/Switzerland/CH/;s/Czech Republic/CZ/;s/Denmark/DK/;s/Spain/ES/;s/France/FR/;
s/Hong Kong/HK/;s/Hungary/HU/;s/Ireland/IE/;s/Israel/IL/;s/India/IN/;s/Italy/IT/;s/Japan/JP/;s/Mexico/MX/;s/Netherlands/NL/;s/Norway/NO/;s/New Zealand/NZ/;
s/Poland/PL/;s/Romania/RO/;s/Serbia/RS/;s/Sweden/SE/;s/Singapore/SG/;s/South Africa/ZA/;s/_/ /g;'
}

# provider_wevpn_get_server country_id country_name city_id city_name protocol vpn_type
# Returns the OVPN filename stem.
provider_wevpn_get_server(){
	_ws_countryname="$2"
	_ws_cityname="$4"
	_ws_prot="$5"

	_ws_stem="$(printf '%s' "$_ws_countryname" | _wevpn_sed_reverse_country_codes)"'_'"$(printf '%s' "$_ws_cityname" | tr 'A-Z' 'a-z')-${_ws_prot}"
	printf '%s' "$_ws_stem"
}

# provider_wevpn_get_ovpn filename_stem protocol vpn_type
# WeVPN is deprecated — prints a clear error and returns 1.
provider_wevpn_get_ovpn(){
	Print_Output true "WeVPN: $_WEVPN_DEPRECATED_MSG" "$ERR"
	return 1
}

# provider_wevpn_get_comp
provider_wevpn_get_comp(){
	printf -- "-1"
}

# provider_wevpn_get_hmac
provider_wevpn_get_hmac(){
	printf "3"
}

# provider_wevpn_get_short_name server_id addr
provider_wevpn_get_short_name(){
	_sn_addr="$2"
	printf '%s' "$_sn_addr" | cut -f1 -d'.' \
		| awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}'
}

# provider_wevpn_write_certs vpn_no ovpn_detail
# Writes ca + crt + static (tls-crypt) + key; removes crl.
provider_wevpn_write_certs(){
	_wc_no="$1"
	_wc_ovpn="$2"

	_wc_ca="$(printf '%s' "$_wc_ovpn" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_ca" ] && Print_Output true "WeVPN: Error determining CA certificate" "$ERR" && return 1

	_wc_crt="$(printf '%s' "$_wc_ovpn" | awk '/<cert>/{flag=1;next}/<\/cert>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_crt" ] && Print_Output true "WeVPN: Error determining client cert" "$ERR" && return 1

	_wc_static="$(printf '%s' "$_wc_ovpn" | awk '/<tls-crypt>/{flag=1;next}/<\/tls-crypt>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_static" ] && Print_Output true "WeVPN: Error determining static (tls-crypt) key" "$ERR" && return 1

	_wc_key="$(printf '%s' "$_wc_ovpn" | awk '/<key>/{flag=1;next}/<\/key>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_key" ] && Print_Output true "WeVPN: Error determining client key" "$ERR" && return 1

	printf '%s\n' "$_wc_ca"     > /jffs/openvpn/vpn_crt_client"${_wc_no}"_ca
	printf '%s\n' "$_wc_crt"    > /jffs/openvpn/vpn_crt_client"${_wc_no}"_crt
	printf '%s\n' "$_wc_static" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_static
	printf '%s\n' "$_wc_key"    > /jffs/openvpn/vpn_crt_client"${_wc_no}"_key
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crl
}

# provider_wevpn_get_country_names
provider_wevpn_get_country_names(){
	_wcd="$SCRIPT_DIR/wevpn_countrydata"
	if [ ! -f "$_wcd" ]; then
		Print_Output true "WeVPN: Country data cache missing" "$ERR"
		return 1
	fi
	cat "$_wcd" | _wevpn_sed_country_codes_destructive \
		| awk '{$1=$1;print}' \
		| awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' \
		| sort -u
}

# provider_wevpn_get_country_id country_name
# WeVPN does not use numeric country IDs.
provider_wevpn_get_country_id(){
	printf "0"
}

# provider_wevpn_get_city_count country_name
provider_wevpn_get_city_count(){
	_wcd="$SCRIPT_DIR/wevpn_countrydata"
	cat "$_wcd" | _wevpn_sed_country_codes_destructive | sort | grep -c "$1"
}

# provider_wevpn_get_city_names country_name
provider_wevpn_get_city_names(){
	_wcd="$SCRIPT_DIR/wevpn_countrydata"
	cat "$_wcd" | _wevpn_sed_country_codes | grep "$1" \
		| sed "s/$1//" \
		| awk '{$1=$1;print}' \
		| awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' \
		| sort
}

# provider_wevpn_get_city_id country_name city_name
# WeVPN does not use numeric city IDs.
provider_wevpn_get_city_id(){
	printf "0"
}

# provider_wevpn_country_required
# Returns 0 — country selection is required.
provider_wevpn_country_required(){
	return 0
}

# provider_wevpn_city_required
# Returns 0 — city selection is required.
provider_wevpn_city_required(){
	return 0
}

# provider_wevpn_get_types
provider_wevpn_get_types(){
	printf "Standard\n"
}

# provider_wevpn_get_server_load desc
# Not supported.
provider_wevpn_get_server_load(){
	printf ""
}

# provider_wevpn_refresh_cache
# Deprecated — WeVPN archives are no longer available.
provider_wevpn_refresh_cache(){
	Print_Output true "WeVPN: $_WEVPN_DEPRECATED_MSG" "$ERR"
	Print_Output true "WeVPN: Cache refresh is not possible for a deprecated provider" "$WARN"
	return 1
}

# provider_wevpn_needs_cache
# Returns 0 always (cache will never be satisfiable for a deprecated provider).
provider_wevpn_needs_cache(){
	return 0
}
