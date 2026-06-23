#!/bin/sh
# PIA (Private Internet Access) provider module for vpnmgr
# Status: UNMAINTAINED — extracted from jackyaz's vpnmgr v2.3.2
#
# Depends on: 7za (p7zip), curl
# Cache files: $OVPN_ARCHIVE_DIR/pia_*.zip, $SCRIPT_DIR/pia_countrydata

##########         Shellcheck directives     ##########
# shellcheck disable=SC2039
# shellcheck disable=SC3043
#######################################################

provider_pia_version(){
	printf "v1.0.0\n"
}

# Internal: translate country name to PIA country code prefix
_pia_sed_country_codes_destructive(){
	sed 's/ /_/g;s/^AU_.*/Australia/I;s/^CA_.*/Canada/I;s/^DE_.*/Germany/I;s/^UAE_.*/United Arab Emirates/I;s/^UK_.*/United Kingdom/I;s/^US_.*/United States/I;
s/^AE_.*/United Arab Emirates/I;s/^GB_.*/United Kingdom/I;s/^AT_.*/Austria/I;s/^BE_.*/Belgium/I;s/^BG_.*/Bulgaria/I;s/^BR_.*/Brazil/I;
s/^CH_.*/Switzerland/I;s/^CZ_.*/Czech Republic/I;s/^DK_.*/Denmark/I;s/^ES_.*/Spain/I;s/^FR_.*/France/I;s/^HK_.*/Hong Kong/I;s/^HU_.*/Hungary/I;
s/^IE_.*/Ireland/I;s/^IL_.*/Israel/I;s/^IN_.*/India/I;s/^IT_.*/Italy/I;s/^JP_.*/Japan/I;s/^MX_.*/Mexico/I;s/^NL_.*/Netherlands/I;s/^NO_.*/Norway/I;s/^NZ_.*/New Zealand/I;
s/^PL_.*/Poland/I;s/^RO_.*/Romania/I;s/^RS_.*/Serbia/I;s/^SE_.*/Sweden/I;s/^SG_.*/Singapore/I;s/^ZA_.*/South Africa/I;s/_/ /g;'
}

_pia_sed_country_codes(){
	sed 's/ /_/g;s/^AU_/Australia/I;s/^CA_/Canada/I;s/^DE_/Germany/I;s/^UAE_/United Arab Emirates/I;s/^UK_/United Kingdom/I;s/^US_/United States/I;
s/^AE_/United Arab Emirates/I;s/^GB_/United Kingdom/I;s/^AT_/Austria/I;s/^BE_/Belgium/I;s/^BG_/Bulgaria/I;s/^BR_/Brazil/I;
s/^CH_/Switzerland/I;s/^CZ_/Czech Republic/I;s/^DK_/Denmark/I;s/^ES_/Spain/I;s/^FR_/France/I;s/^HK_/Hong Kong/I;s/^HU_/Hungary/I;
s/^IE_/Ireland/I;s/^IL_/Israel/I;s/^IN_/India/I;s/^IT_/Italy/I;s/^JP_/Japan/I;s/^MX_/Mexico/I;s/^NL_/Netherlands/I;s/^NO_/Norway/I;s/^NZ_/New Zealand/I;
s/^PL_/Poland/I;s/^RO_/Romania/I;s/^RS_/Serbia/I;s/^SE_/Sweden/I;s/^SG_/Singapore/I;s/^ZA_/South Africa/I;s/_/ /g;'
}

_pia_sed_reverse_country_codes(){
	sed 's/Australia/AU/;s/Canada/CA/;s/Germany/DE/;s/United Kingdom/UK/;s/United States/US/;'
}

# provider_pia_get_server country_id country_name city_id city_name protocol vpn_type
# Returns the OVPN filename stem (without .ovpn extension).
provider_pia_get_server(){
	_ps_countryname="$2"
	_ps_cityname="$4"

	_ps_stem="$(printf '%s' "$_ps_countryname" | _pia_sed_reverse_country_codes)"
	if [ -n "$_ps_cityname" ]; then
		_ps_stem="${_ps_stem}_${_ps_cityname}"
	fi
	_ps_stem="$(printf '%s' "$_ps_stem" | tr 'A-Z' 'a-z' | sed 's/ /_/g')"
	printf '%s' "$_ps_stem"
}

# provider_pia_get_ovpn filename_stem protocol vpn_type
# Extracts OVPN from the appropriate ZIP archive and prints to stdout.
provider_pia_get_ovpn(){
	_po_stem="$1"
	_po_prot="$2"
	_po_type="$3"
	_po_prot_lc="$(printf '%s' "$_po_prot" | tr 'A-Z' 'a-z')"
	_po_type_lc="$(printf '%s' "$_po_type" | tr 'A-Z' 'a-z')"
	_po_archive="$OVPN_ARCHIVE_DIR/pia_${_po_prot_lc}_${_po_type_lc}.zip"

	if [ ! -f "$_po_archive" ]; then
		Print_Output true "PIA: Archive not found: $_po_archive" "$ERR"
		return 1
	fi

	/opt/bin/7za e -bsp0 -bso0 "$_po_archive" -o/tmp "${_po_stem}.ovpn"
	if [ ! -f "/tmp/${_po_stem}.ovpn" ]; then
		Print_Output true "PIA: Could not extract ${_po_stem}.ovpn from archive" "$ERR"
		return 1
	fi
	cat "/tmp/${_po_stem}.ovpn"
	rm -f "/tmp/${_po_stem}.ovpn"
}

# provider_pia_get_comp
provider_pia_get_comp(){
	printf "no"
}

# provider_pia_get_hmac
provider_pia_get_hmac(){
	printf "1"
}

# provider_pia_get_short_name server_id addr
# PIA uses the IP address as the identifier rather than a hostname.
provider_pia_get_short_name(){
	_sn_addr="$2"
	if printf '%s' "$_sn_addr" | grep -q "-"; then
		printf '%s' "$_sn_addr" | cut -f1 -d'.' \
			| awk '{print toupper(substr($0,0,2))tolower(substr($0,3))}'
	else
		printf '%s' "$_sn_addr" | cut -f1 -d'.' \
			| awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}'
	fi
}

# provider_pia_write_certs vpn_no ovpn_detail
# Writes ca + crl; removes static, key, crt.
provider_pia_write_certs(){
	_wc_no="$1"
	_wc_ovpn="$2"

	_wc_ca="$(printf '%s' "$_wc_ovpn" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_ca" ] && Print_Output true "PIA: Error determining CA certificate" "$ERR" && return 1

	_wc_crl="$(printf '%s' "$_wc_ovpn" | awk '/<crl-verify>/{flag=1;next}/<\/crl-verify>/{flag=0}flag' | sed '/^#/ d')"
	[ -z "$_wc_crl" ] && Print_Output true "PIA: Error determining CRL" "$ERR" && return 1

	printf '%s\n' "$_wc_ca"  > /jffs/openvpn/vpn_crt_client"${_wc_no}"_ca
	printf '%s\n' "$_wc_crl" > /jffs/openvpn/vpn_crt_client"${_wc_no}"_crl
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_static
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_key
	rm -f /jffs/openvpn/vpn_crt_client"${_wc_no}"_crt
}

# provider_pia_get_country_names
# Reads pia_countrydata (flat list of OVPN stems), decodes country names.
provider_pia_get_country_names(){
	_pcd="$SCRIPT_DIR/pia_countrydata"
	if [ ! -f "$_pcd" ]; then
		Print_Output true "PIA: Country data cache missing — run refreshcacheddata" "$ERR"
		return 1
	fi
	cat "$_pcd" | _pia_sed_country_codes_destructive \
		| awk '{$1=$1;print}' \
		| awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' \
		| sort -u
}

# provider_pia_get_country_id country_name
# PIA does not use numeric country IDs.
provider_pia_get_country_id(){
	printf "0"
}

# provider_pia_get_city_count country_name
provider_pia_get_city_count(){
	_pcd="$SCRIPT_DIR/pia_countrydata"
	cat "$_pcd" | _pia_sed_country_codes_destructive | sort | grep -c "$1"
}

# provider_pia_get_city_names country_name
provider_pia_get_city_names(){
	_pcd="$SCRIPT_DIR/pia_countrydata"
	cat "$_pcd" | _pia_sed_country_codes | grep "$1" \
		| sed "s/$1//" \
		| awk '{$1=$1;print}' \
		| awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' \
		| sort
}

# provider_pia_get_city_id country_name city_name
# PIA does not use numeric city IDs.
provider_pia_get_city_id(){
	printf "0"
}

# provider_pia_country_required
# Returns 0 — country selection is required for PIA.
provider_pia_country_required(){
	return 0
}

# provider_pia_city_required
# Returns 0 — city selection is required for PIA.
provider_pia_city_required(){
	return 0
}

# provider_pia_get_types
provider_pia_get_types(){
	printf "Standard\nStrong\n"
}

# provider_pia_get_server_load desc
# Not supported by PIA.
provider_pia_get_server_load(){
	printf ""
}

# provider_pia_refresh_cache
# Downloads 4 PIA ZIP archives, compares with cached copies, updates pia_countrydata.
provider_pia_refresh_cache(){
	Print_Output true "PIA: Refreshing OpenVPN file archives..."

	/usr/sbin/curl -fsL --retry 3 \
		https://www.privateinternetaccess.com/openvpn/openvpn.zip \
		-o /tmp/pia_udp_standard.zip
	/usr/sbin/curl -fsL --retry 3 \
		https://www.privateinternetaccess.com/openvpn/openvpn-tcp.zip \
		-o /tmp/pia_tcp_standard.zip
	/usr/sbin/curl -fsL --retry 3 \
		https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip \
		-o /tmp/pia_udp_strong.zip
	/usr/sbin/curl -fsL --retry 3 \
		https://www.privateinternetaccess.com/openvpn/openvpn-strong-tcp.zip \
		-o /tmp/pia_tcp_strong.zip

	_prc_changed="$(CompareArchiveContents "/tmp/pia_udp_standard.zip /tmp/pia_tcp_standard.zip /tmp/pia_udp_strong.zip /tmp/pia_tcp_strong.zip")"

	if [ "$_prc_changed" = "true" ]; then
		/opt/bin/7za -ba l "$OVPN_ARCHIVE_DIR/pia_udp_standard.zip" -- "*.ovpn" \
			| awk '{ for (i = 6; i <= NF; i++) { printf "%s ",$i } printf "\n"}' \
			| sed 's/\.ovpn//' \
			| sort \
			| awk '{$1=$1;print}' \
			> "$SCRIPT_DIR/pia_countrydata"
		Print_Output true "PIA: Archives updated" "$PASS"
	else
		Print_Output true "PIA: Archives unchanged" "$WARN"
	fi
}

# provider_pia_needs_cache
# Returns 0 (needs refresh) if the standard UDP archive is missing.
provider_pia_needs_cache(){
	if [ ! -f "$OVPN_ARCHIVE_DIR/pia_udp_standard.zip" ]; then
		return 0
	fi
	return 1
}
