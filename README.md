# vpnmgr
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/f73bdf3124904744b1844b4099f77bfe)](https://www.codacy.com/gh/jackyaz/vpnmgr/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jackyaz/vpnmgr&amp;utm_campaign=Badge_Grade)
![Shellcheck](https://github.com/jackyaz/vpnmgr/actions/workflows/shellcheck.yml/badge.svg)

## v2.3.2
### Updated on 2021-08-05
## About
vpnmgr enables easy management of your VPN Client connections for various VPN providers on AsusWRT-Merlin. The following VPN Providers are currently supported: NordVPN, Private Internet Access (PIA) and WeVPN.
NordVPN clients can be configured to automatically refresh on a scheduled basis with the recommended server as provided by the NordVPN API.

The concept for this script was originally developed by [@h0me5k1n](https://github.com/h0me5k1n/asusmerlin-nvpnmgr)

### Supporting development
Love the script and want to support future development? Any and all donations gratefully received!

| [![paypal](https://www.paypalobjects.com/en_GB/i/btn/btn_donate_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) <br /><br /> [**PayPal donation**](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) | [![paypal](https://puu.sh/IAhtp/3788f3a473.png)](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) |
| :----: | --- |

## Supported firmware versions
You must be running firmware Merlin 384.15/384.13_4 or Fork 43E5 (or later) [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation
Using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/jackyaz/vpnmgr/master/vpnmgr.sh" -o "/jffs/scripts/vpnmgr" && chmod 0755 /jffs/scripts/vpnmgr && /jffs/scripts/vpnmgr install
```

## Usage
vpnmgr adds a tab to VPN menu of the WebUI.

Otherwise, to launch the vpnmgr menu, use:
```sh
vpnmgr
```

If this does not work, you will need to use the full path:
```sh
/jffs/scripts/vpnmgr
```

## Screenshots

![WebUI](https://puu.sh/HevUo/0600bbea5c.png)

![CLI UI](https://puu.sh/HevPC/4f5ddfc3d6.png)

## Help
Please post about any issues and problems here: [Asuswrt-Merlin AddOns on SNBForums](https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=11)
