# asusmerlin-nvpnmgr
Automatically update client connection to recommended NordVPN server on Asus Merlin router firmware. Tested on RT-AC68U running v384.16 from https://www.asuswrt-merlin.net/download

## Pre Requisites

a NordVPN account is required to establish a connection.

an existing VPN connection with the string "nordvpn" needs to exist in on of the 5 VPN client configurations. Configure this initially using the information from NordVPN about configuring the connection.

## Usage (CLI)

where [1|2|3|4|5] is noted, this refers to the instance of the VPN connection
where [openvpn_udp|openvpn_tcp] is noted, this refers to the VPN protocol (as named by NordVPN in their API)
where [minute] is noted, this refers to the minute in the hour when a scheduled update should take place
where [hour] is noted, this refers to the hour in the day/s when a scheduled update should take place
where [day numbers] is noted, this refers to the days when an update will take place from 1 to 7 (1 = Monday). Multiple days can be specified separating days with a comma (e.g. "1,5" is Monday and Friday)

### Manual Server Update
to manually trigger an update
```
nordvpnmanager.sh update [1|2|3|4|5] [openvpn_udp|openvpn_tcp]
```
if a connection is currently running, it will be reconnect to the recommended server

### Configure a Scheduled Server Update
to schedule updates using cron/cru
```
nordvpnmanager.sh schedule [1|2|3|4|5] [openvpn_udp|openvpn_tcp] [minute] [hour] [day numbers]
```
This will not affect any existing connections until the scheduled time is reached and the VPN is connected

### Cancel Scheduled Server Update
to cancel scheduled updates configured in cron/cru
```
nordvpnmanager.sh cancel [1|2|3|4|5] 
```
This will not affect any existing connections

## Installation (WebUI - untested)
This has not yet been created as the web page that needs to be installed has not yet been created.
The actual script has been created

## To Do
query available protocols via NordVPN api
handle protocols
? write options to temp nvram ?
create web page for UI
test web page functions

