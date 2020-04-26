# asusmerlin-nvpnmgr
Automatically update VPN client connection to recommended NordVPN server on Asus Merlin router firmware. Tested on RT-AC68U running v384.16 from https://www.asuswrt-merlin.net/download

## Prerequisites

a NordVPN account is required to establish a connection.

an Asus router running v384.15 or later of the Merlin firmware.

The JFFS partition needs to be enabled.

a VPN connection with the string "nordvpn" needs to exist in 1 of the 5 VPN client configurations on the router for the script to successfully run (install possible as long as the above prerequisites are in place). Configure this initially using the information from NordVPN about configuring the connection. Future executions of the script will also use the required naming convention.

## Installation (Script)
To install the required files, run the following command on the Asus router running Merlin firmware:

```
wget -O - https://raw.githubusercontent.com/h0me5k1n/asusmerlin-nvpnmgr/master/install.sh | sh
```

## Usage (CLI)

where [1|2|3|4|5] is noted, this refers to the instance of the VPN connection
where [openvpn_udp|openvpn_tcp] is noted, this refers to the VPN protocol (as named by NordVPN in their API). This is currently fixed to use the "openvpn_udp" VPN profiles. Future version may support multiple protocols (see "To Do" section).
where [minute] is noted, this refers to the minute in the hour when a scheduled update should take place
where [hour] is noted, this refers to the hour in the day/s when a scheduled update should take place
where [day numbers] is noted, this refers to the days when an update will take place from 1 to 7 (1 = Monday). Multiple days can be specified separating days with a comma (e.g. "1,5" is Monday and Friday)

### Manual Server Update
to manually trigger an update
```
nordvpnmanager.sh update [1|2|3|4|5] [openvpn_udp|openvpn_tcp]
```
if a connection is currently running, it will update and reconnect to the recommended server.

This is currently fixed to use the "openvpn_udp" VPN profiles. Future version may support multiple protocols (see "To Do" section)

### Configure a Scheduled Server Update
to schedule updates using cron/cru
```
nordvpnmanager.sh schedule [1|2|3|4|5] [openvpn_udp|openvpn_tcp] [minute] [hour] [day numbers]
```
This will not affect any existing connections until the scheduled time is reached and the VPN is connected

This is currently fixed to use the "openvpn_udp" VPN profiles. Future version may support multiple protocols (see "To Do" section)

### Cancel Scheduled Server Update
to cancel scheduled updates configured in cron/cru
```
nordvpnmanager.sh cancel [1|2|3|4|5] 
```
This will not affect any existing connections

## Installation (WebUI - untested)
This has not yet been created as the web page that needs to be installed has not yet been created.
The actual script has been created but will not complete successfully without the web page.

## To Do
Possible enhancements (when I get round to it!):

- query available protocols via NordVPN api
- handle multiple protocols
- write options to temp nvram (I haven't figured out how a web page passes parameters to an addon script. This might be needed instead of passing them from the page. e.g. page write temp nvram entries that are used by the script and then discarded?!?)
- create web page for UI (I need help with this!)
- test web page functions
