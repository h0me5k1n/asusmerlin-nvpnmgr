# asusmerlin-nvpnmgr
Automatically update client connection to recommended NordVPN server on Asus Merlin router firmware

# Pre Requisites

a NordVPN account is required to establish a connection.

an existing VPN connection with the string "nordvpn" needs to exist in on of the 5 VPN client configurations. Configure this initially using the information from NordVPN about configuring the connection.

# Usage (CLI)

where [1|2|3|4|5] is noted, this refers to the instance of the VPN connection

to manually trigger an update
nordvpnmanager.sh update [1|2|3|4|5] [openvpn_udp|openvpn_tcp]
if a connection is currently running, it will be reconnect to the recommended server

to schedule updates using cron/cru
nordvpnmanager.sh schedule [1|2|3|4|5] [openvpn_udp|openvpn_tcp] [minute] [hour] [day numbers]
This will not affect any existing connections until the scheduled time is reached and the VPN is connected

to cancel scheduled updates configured in cron/cru
nordvpnmanager.sh cancel [1|2|3|4|5] 
This will not affect any existing connections

# Installation (WebUI - untested)
This has not yet been created as the web page that needs to be installed has not yet been created.
The actual script has been created

# To Do
query available protocols via NordVPN api
handle protocols
? write options to temp nvram ?
create web page for UI
test web page functions

