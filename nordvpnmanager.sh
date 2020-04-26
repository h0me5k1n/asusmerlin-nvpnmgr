#!/bin/sh

# USAGE
#
# to manually trigger an update
# scriptname update [1|2|3|4|5] [openvpn_udp|openvpn_tcp]
# to schedule updates using cron/cru
# scriptname schedule [1|2|3|4|5] [openvpn_udp|openvpn_tcp] [minute] [hour] [day numbers]
# to cancel schedule updates using cron/cru
# scriptname cancel [1|2|3|4|5] 

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
# load standard variables and helper script
source /usr/sbin/helper.sh
source "$SCRIPTPATH/addon_vars"
JSONSCRIPT="$SCRIPTPATH/JSON.sh"

cd "$SCRIPTPATH"

# variables
EVENT=$MY_ADDON_NAME
TYPE=$1
VPN_NO=$2
VPNPROT=$3

VPNPROT=openvpn_udp # use openvpn_udp or openvpn_tcp - this sets the default to openvpn_udp no matter what you pass to the script
VPNPROT_SHORT=${VPNPROT/*_/}

# check processing is for this addon
# stop processing if event unmatched
if [ "$EVENT" != "$MY_ADDON_NAME" ]
then
 exit 0
fi

# functions
errorcheck(){
 echo "$SCRIPTSECTION reported an error..."
 logger -t "$MY_ADDON_NAME addon" "$SCRIPTSECTION reported an error"
 exit 1
}

# use to create content of vJSON variable
getRecommended(){
 SCRIPTSECTION=getRecommended
 curl -s -m 5 "https://api.nordvpn.com/v1/servers/recommendations?filters\[servers_groups\]\[identifier\]=legacy_standard&filters\[servers_technologies\]\[identifier\]=${VPNPROT}&limit=1" || errorcheck
 SCRIPTSECTION=
}

# use to download the JSON.sh script from github
getJSONSH(){
 SCRIPTSECTION=getJSONSH
 [ -f "$JSONSCRIPT" ] && rm "$JSONSCRIPT"
 wget -O "$JSONSCRIPT" "https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh" >/dev/null 2>&1 || errorcheck
 chmod +x "$JSONSCRIPT"
 SCRIPTSECTION=
}

# use to create content of OVPN_IP variable
getIP(){
 SCRIPTSECTION=getJSONSH
 # check vJSON variable contents exist
 [ -z "$vJSON" ] && errorcheck
 # check JSONSCRIPT script exists
 [ ! -f "$JSONSCRIPT" ] && errorcheck
 echo $vJSON | "$JSONSCRIPT" -b | grep station | cut -f2 | tr -d '"'
 SCRIPTSECTION=
}

# use to create content of OVPN_HOSTNAME variable
getHostname(){
 SCRIPTSECTION=getHostname
 [ -z "$vJSON" ] && errorcheck
 echo $vJSON | "$JSONSCRIPT" -b | grep hostname | cut -f2 | tr -d '"'
 SCRIPTSECTION=
}

# use to create content of OVPNFILE variable
getOVPNFilename(){
 SCRIPTSECTION=getOVPNFile
 [ -z "$OVPN_HOSTNAME" -o -z "$VPNPROT_SHORT" ] && errorcheck
 echo ${OVPN_HOSTNAME}.${VPNPROT_SHORT}.ovpn
 SCRIPTSECTION=
}

# use to create content of OVPN_DETAIL variable
getOVPNcontents(){
 SCRIPTSECTION=getOVPNcontents
 [ -z "$OVPNFILE" -o -z "$VPNPROT_SHORT" ] && errorcheck
 curl -s -m 5 "https://downloads.nordcdn.com/configs/files/ovpn_$VPNPROT_SHORT/servers/$OVPNFILE" || errorcheck
 SCRIPTSECTION=
}

# use to create content of CLIENT_CA variable
getClientCA(){
 SCRIPTSECTION=getOVPNcontents
 [ -z "$OVPN_DETAIL" ] && errorcheck
 echo "$OVPN_DETAIL" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d' 
 SCRIPTSECTION=
}

# use to create content of CRT_CLIENT_STATIC variable
getClientCRT(){
 SCRIPTSECTION=getOVPNcontents
 [ -z "$OVPN_DETAIL" ] && errorcheck
 echo "$OVPN_DETAIL" | awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag' | sed '/^#/ d' 
 SCRIPTSECTION=
}

# use to create content of EXISTING_NAME variable
getConnName(){
 SCRIPTSECTION=getConnName
 [ -z "$VPN_NO" ] && errorcheck
 nvram get vpn_client${VPN_NO}_desc || errorcheck
 SCRIPTSECTION=
}

# EXISTING_NAME check - it must contain "nordvpn"
checkConnName(){
 SCRIPTSECTION=checkConnName
 [ -z "$VPN_NO" ] && errorcheck
 EXISTING_NAME=$(getConnName)
 STR_COMPARE=nordvpn
 if echo $EXISTING_NAME | grep -v $STR_COMPARE >/dev/null 2>&1
 then
  logger -t "$MY_ADDON_NAME addon" "decription must contain nordvpn (VPNClient$VPN_NO)..."
  errorcheck
 fi
 SCRIPTSECTION=
}

# use to create content of EXISTING_IP variable
getServerIP(){
 SCRIPTSECTION=getServerIP
 [ -z "$VPN_NO" ] && errorcheck
 nvram show | grep vpn_client${VPN_NO}_addr | cut -d= -f2 || errorcheck
 SCRIPTSECTION=
}

# use to create content of CONNECTSTATE variable - set to 2 if the VPN is connected
getConnectState(){
 SCRIPTSECTION=getConnectState
 [ -z "$VPN_NO" ] && errorcheck
 nvram show | grep vpn_client${VPN_NO}_state | cut -d= -f2 || errorcheck
 SCRIPTSECTION=
}

# configure VPN
setVPN(){
 vJSON=$(getRecommended)
 getJSONSH
 OVPN_IP=$(getIP)
 OVPN_HOSTNAME=$(getHostname)
 OVPNFILE=$(getOVPNFilename)
 OVPN_DETAIL=$(getOVPNcontents)
 CLIENT_CA=$(getClientCA)
 CRT_CLIENT_STATIC=$(getClientCRT)
 EXISTING_NAME=$(getConnName)
 EXISTING_IP=$(getServerIP)
 CONNECTSTATE=$(getConnectState)
 
 SCRIPTSECTION=setVPN1
 [ -z "$OVPN_IP" -o -z "$OVPN_HOSTNAME" -o -z "$VPN_NO" ] && errorcheck
 SCRIPTSECTION=setVPN2
 [ -z "$CLIENT_CA" -o -z "$CRT_CLIENT_STATIC" ] && errorcheck
 SCRIPTSECTION=setVPN3
 [ -z "$CONNECTSTATE" ] && errorcheck
 # check that new VPN server IP is different
 if [ "$OVPN_IP" != "$EXISTING_IP" ]
 then
  SCRIPTSECTION=setVPN4
  echo "updating VPN Client connection $VPN_NO to $OVPN_HOSTNAME"
  nvram set vpn_client${VPN_NO}_addr=${OVPN_IP} || errorcheck
  nvram set vpn_client${VPN_NO}_desc=${OVPN_HOSTNAME} || errorcheck
  echo "$CLIENT_CA" > /jffs/openvpn/vpn_crt_client${VPN_NO}_ca
  echo "${CRT_CLIENT_STATIC}" > /jffs/openvpn/vpn_crt_client${VPN_NO}_static
  nvram commit
  # restart if connected - 2 is "connected"
  if [ "$CONNECTSTATE" = "2" ]
  then
   service stop_vpnclient${VPN_NO}
   sleep 3
   service start_vpnclient${VPN_NO}
  fi
 else
  echo "recommended server for VPN Client connection $VPN_NO is already the recommended server - $OVPN_HOSTNAME"
 fi
 SCRIPTSECTION=
}

getCRONentry(){
 SCRIPTSECTION=getCRONentry
 [ -z "$VPN_NO" -o -z "$MY_ADDON_NAME" ] && errorcheck
 cru l | grep "${MY_ADDON_NAME}${VPN_NO}" | sed 's/ sh.*//'
 [ $? -ne 0 ] && echo NOTFOUND
 SCRIPTSECTION=
}

setCRONentry(){
 SCRIPTSECTION=setCRONentry
 [ -z "$VPN_NO" -o -z "$MY_ADDON_NAME" -o -z "$SCRIPTPATH" -o -z "$MY_ADDON_SCRIPT" -o -z "$VPNPROT" ] && errorcheck
 [ -z "$CRU_MINUTE" -o -z "$CRU_HOUR" -o -z "$CRU_DAYNUMBERS" ] && errorcheck
 # add new cru entry
 if cru l | grep "${MY_ADDON_NAME}${VPN_NO}" >/dev/null 2>&1 
 then
  # replace existing
  cru d ${MY_ADDON_NAME}${VPN_NO}
  cru a ${MY_ADDON_NAME}${VPN_NO} "${CRU_MINUTE} ${CRU_HOUR} * * ${CRU_DAYNUMBERS} sh ${SCRIPTPATH}/${MY_ADDON_SCRIPT} update ${VPN_NO} ${VPNPROT}"
 else
  # or add new if not exist
  cru a ${MY_ADDON_NAME}${VPN_NO} "${CRU_MINUTE} ${CRU_HOUR} * * ${CRU_DAYNUMBERS} sh ${SCRIPTPATH}/${MY_ADDON_SCRIPT} update ${VPN_NO} ${VPNPROT}"
 fi
 # add persistent cru entry to /jffs/scripts/services-start for restarts
 if cat /jffs/scripts/services-start | grep "${MY_ADDON_NAME}${VPN_NO}" >/dev/null 2>&1 
 then
  # remove and replace existing
  sed -i "/${MY_ADDON_NAME}${VPN_NO}/d" /jffs/scripts/services-start      
  echo "cru a ${MY_ADDON_NAME}${VPN_NO} \"${CRU_MINUTE} ${CRU_HOUR} * * ${CRU_DAYNUMBERS} sh ${SCRIPTPATH}/${MY_ADDON_SCRIPT} update ${VPN_NO} ${VPNPROT}\"" >> /jffs/scripts/services-start
 else
  # or add new if not exist
  echo "cru a ${MY_ADDON_NAME}${VPN_NO} \"${CRU_MINUTE} ${CRU_HOUR} * * ${CRU_DAYNUMBERS} sh ${SCRIPTPATH}/${MY_ADDON_SCRIPT} update ${VPN_NO} ${VPNPROT}\"" >> /jffs/scripts/services-start
 fi
 am_settings_set nvpn_cron${VPN_NO} 1
 am_settings_set nvpn_cronstr${VPN_NO} "${CRU_MINUTE} ${CRU_HOUR} * * ${CRU_DAYNUMBERS}"
 SCRIPTSECTION=
}

delCRONentry(){
 SCRIPTSECTION=delCRONentry
 [ -z "$VPN_NO" -o -z "$MY_ADDON_NAME" ] && errorcheck
 # remove cru entry
 if cru l | grep "${MY_ADDON_NAME}${VPN_NO}" >/dev/null 2>&1 
 then
  # remove existing
  cru d ${MY_ADDON_NAME}${VPN_NO}
 fi
 # remove persistent cru entry from /jffs/scripts/services-start for restarts
 if cat /jffs/scripts/services-start | grep "${MY_ADDON_NAME}${VPN_NO}" >/dev/null 2>&1 
 then
  # remove and replace existing
  sed -i "/${MY_ADDON_NAME}${VPN_NO}/d" /jffs/scripts/services-start      
 fi
 am_settings_set nvpn_cron${VPN_NO}
 am_settings_set nvpn_cronstr${VPN_NO}
 SCRIPTSECTION=
}

# ----------------
# ----------------
# ----------------

# logic processing
if [ "$TYPE" = "update" ]
then
 checkConnName
 logger -t "$MY_ADDON_NAME addon" "Updating to recommended NORDVPN server (VPNClient$VPN_NO)..."
 setVPN
 logger -t "$MY_ADDON_NAME addon" "Update complete (VPNClient$VPN_NO - server $OVPN_HOSTNAME)"
fi

if [ "$TYPE" = "schedule" ]
then
 checkConnName
 CRU_MINUTE=$4
 CRU_HOUR=$5
 CRU_DAYNUMBERS=$6
 
 # default options 5:25am on Mondays and Thursdays
 [ -z "$CRU_MINUTE" ] && CRU_MINUTE=25
 [ -z "$CRU_HOUR" ] && CRU_HOUR=5
 [ -z "$CRU_DAYNUMBERS" ] && CRU_DAYNUMBERS=1,4

# CRON entry format = 5 5 * * 1,3,5 sh /jffs/scripts/asusvpn-autoselectbest.sh #autoselectvpn#
# command to add (in /jffs/scripts/services-start) cru a autoselectvpn "5 5 * * 1,3,5 sh /jffs/scripts/asusvpn-autoselectbest.sh"

# cru command syntax to add, list, and delete cron jobs
# id – Unique ID for each cron job.
# min – Minute (0-59)
# hour – Hours (0-23)
# day – Day (0-31)
# month – Month (0-12 [12 is December])
# week – Day of the week(0-7 [7 or 0 is Sunday])
# command – Script or command name to schedule.

 logger -t "$MY_ADDON_NAME addon" "Configuring scheduled update to recommended NORDVPN server (VPNClient$VPN_NO)..."
 setCRONentry
 logger -t "$MY_ADDON_NAME addon" "Scheduling complete (VPNClient$VPN_NO)"
fi

if [ "$TYPE" = "cancel" ]
then
 checkConnName
 [ -z "$VPN_NO" ] && errorcheck
 logger -t "$MY_ADDON_NAME addon" "Removing scheduled update to recommended NORDVPN server (VPNClient$VPN_NO)..."
 delCRONentry
 logger -t "$MY_ADDON_NAME addon" "Removal of schedule complete (VPNClient$VPN_NO)"
fi

