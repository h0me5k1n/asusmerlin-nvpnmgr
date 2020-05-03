#!/bin/sh
# menu system
# inspired by approaches in repos from https://github.com/jackyaz

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
# load standard variables and helper script
source /usr/sbin/helper.sh
source "$SCRIPTPATH/addon_vars"
CONTROLSCRIPT="$LOCAL_REPO/$MY_ADDON_SCRIPT"

# default variables for this script
OPTIONCHECK=0

PressEnter(){
	while true; do
		printf "Press enter to continue..."
		read -r "key"
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

ReturnToMainMenu(){
	OPTIONCHECK=1
	RETURNTEXT="$1"
	break 
	ScriptHeader
	UpdateNowMenuHeader
}

SetVPNClient(){
	printf "\\n\\e[1mPlease select a VPN client connection (x to cancel): \\e[0m"
	read -r "VPN_NO"
	if [ "$VPN_NO" = "x" ]; then
		OPTIONCHECK=1
		ReturnToMainMenu "previous operation cancelled"
	elif [ -z "$VPN_NO" ]; then
		ReturnToMainMenu "you must specify a valid VPN client"
	fi
	# validate VPN_NO here (must be a number from 1 to 5 have "nordvpn" in the name)
}

SetVPNProtocol(){
	printf "\\n\\e[1mPlease select a VPN protocol (x to cancel): \\e[0m\\n"
	printf "   1. UDP\\n"
	printf "   2. TCP\\n"
	read -r "menu"

	while true; do
		case "$menu" in
			1)
				# check for connections
				VPNPROT=openvpn_udp
				break
			;;
			2)
				# configure now
				VPNPROT=openvpn_tcp
				break
			;;
			x)
				ReturnToMainMenu "previous operation cancelled"
				break
			;;
			*)
				ReturnToMainMenu "you must choose a protocol option"
				break
			;;
		esac
	done

	if [ -z "$VPNPROT" ]; then
		ReturnToMainMenu "you must choose a protocol option"
	fi
}

SetVPNType(){
	printf "\\n\\e[1mPlease select a VPN Type (x to cancel): \\e[0m\\n"
	printf "   1. Standard VPN (default)\\n"
	printf "   2. Double VPN\\n"
	printf "   3. P2P\\n"
	read -r "menu"

	while true; do
		case "$menu" in
			1)
				# check for connections
				VPNTYPE=standard
				break
			;;
			2)
				# configure now
				VPNTYPE=double
				break
			;;
			3)
				# configure now
				VPNTYPE=p2p
				break
			;;
			x)
				ReturnToMainMenu "previous operation cancelled"
				break
			;;
			*)
				VPNTYPE=standard
				break
			;;
		esac
	done
	if [ -z "$VPNTYPE" ]; then
		ReturnToMainMenu "type not set or previous operation cancelled"
	fi
}

SetDays(){
	printf "\\n\\e[1mPlease choose update day/s (x to cancel - blank for every day): \\e[0m"
	read -r "CRU_DAYNUMBERS"
	if [ "$CRU_DAYNUMBERS" = "x" ]; then
		ReturnToMainMenu "previous operation cancelled"
	elif [ -z "$CRU_DAYNUMBERS" ]; then
		CRU_DAYNUMBERS="*"
		printf "\\n\\e[1mSet to every day\\e[0m\\n"
	fi
	# validate DAYS here (must be a number from 0 to 7 or these numbers separated by comma/s)
}

SetHours(){
	printf "\\n\\e[1mPlease choose update hour/s (x to cancel): \\e[0m"
	read -r "CRU_HOUR"
	if [ "$CRU_HOUR" = "x" ]; then
		ReturnToMainMenu "previous operation cancelled"
	elif [ -z "$CRU_HOUR" ]; then
		ReturnToMainMenu "you must specify a valid hour or hours separated by comma"
	fi
	# validate HOURS here (must be a number from 0 to 23)
}

SetMinutes(){
	printf "\\n\\e[1mPlease choose update minute/s (x to cancel): \\e[0m"
	read -r "CRU_MINUTE"
	if [ "$CRU_MINUTE" = "x" ]; then
		OPTIONCHECK=1
		ReturnToMainMenu "previous operation cancelled"
	elif [ -z "$CRU_MINUTE" ]; then
		ReturnToMainMenu "you must specify a valid minute or minutes separated by comma"
	fi
	# validate MINUTES here (must be a number from 0 to 59)
}

ScriptHeader(){
	clear
	printf "\\n"
	printf "\\e[1m############################################################\\e[0m\\n"
	printf "\\e[1m##                   $MY_ADDON_NAME Menu                  ##\\e[0m\\n"
	printf "\\e[1m############################################################\\e[0m\\n"
	printf "\\n"
}

MainMenu(){
	printf "   1. Check for available NordVPN VPN client connections\\n"
	printf "   2. Update a VPN client connection NOW\\n"
	printf "   3. Schedule a VPN client connection update\\n"
	printf "   d. Delete a scheduled VPN client connection update\\n"
	printf "   u. Update $MY_ADDON_NAME\\n"
	printf "   x. Exit $MY_ADDON_NAME menu\\n\\n"
	printf "   z. Uninstall $MY_ADDON_NAME\\n"
	printf "\\n"
	printf "\\e[1m############################################################\\e[0m\\n"

	VPN_NO=
	VPNPROT=
	VPNTYPE=
	CRU_HOUR=
	CRU_DAYNUMBERS=
	CRU_MINUTE=

	while true; do
		if [ "$OPTIONCHECK" = "1" ] 
		then 
			printf "$RETURNTEXT\\n"
			OPTIONCHECK=0
		else
			printf "\\n"
		fi
		printf "Choose an option:    "
		read -r "menu"
		case "$menu" in
			1)
				printf "\\n"
                # check for connections
				ListMenu
				break
			;;
			2)
				printf "\\n"
                # configure now
				UpdateNowMenu
				break
			;;
			3)
				printf "\\n"
                # configure schedule
				ScheduleUpdateMenu
				break
			;;
			d)
				printf "\\n"
                # remove schedule
				DeleteScheduleMenu
				break
			;;
			u)
				printf "\\n"
                # update script from github
				"$LOCAL_REPO/install.sh"
				PressEnter
				break
			;;
			x)
				ScriptHeader
				printf "\\n\\e[1mThanks for using $MY_ADDON_NAME!\\e[0m\\n\\n\\n"
				exit 0
			;;
			z)
				printf "\\n\\e[1mAre you sure you want to uninstall $MY_ADDON_NAME (Y to confirm)?\\e[0m "
				read -r "confirm"
				if [ "$confirm" = "Y" ]
				then
					echo "Uninstalling $MY_ADDON_NAME..."
					# remove script
					Addon_Uninstall
					exit 0
				else
					ReturnToMainMenu "Uninstall of $MY_ADDON_NAME cancelled"
				fi
			;;
			*)
				ReturnToMainMenu "Please choose a valid option"
			;;
		esac
	done
	
	ScriptHeader
	MainMenu
}

UpdateNowMenuHeader(){
	printf "   Choose options as follows:\\n"
	printf "     VPN client [1-5]\\n"
	printf "     protocol to use (pick from list)\\n"
	printf "     type to use (pick from list)\\n"
	printf "\\n"
	printf "\\e[1m############################################################\\e[0m\\n"
}

ScheduleUpdateMenuHeader(){
	printf "   Choose options as follows:\\n"
	printf "     VPN client [1-5]\\n"
	printf "     protocol to use (pick from list)\\n"
	printf "     type to use (pick from list)\\n"
	printf "     day/s to update [0-7]\\n"
	printf "     hour/s to update [0-23]\\n"
	printf "     minute/s to update [0-59]\\n"
	printf "\\n"
	printf "\\e[1m############################################################\\e[0m\\n"
}

DeleteScheduleMenuHeader(){
	printf "   Choose schedule entry to delete:\\n"
	printf "     VPN client [1-5]\\n"
	printf "\\n"
	printf "\\e[1m############################################################\\e[0m\\n"
}

ListMenu(){
	ScriptHeader
		
	$CONTROLSCRIPT list
	printf "\\n"
	PressEnter

	ReturnToMainMenu
}

UpdateNowMenu(){
	ScriptHeader
	UpdateNowMenuHeader
	
	SetVPNClient
	SetVPNProtocol
	SetVPNType
	
	$CONTROLSCRIPT update "$VPN_NO" "$VPNPROT" "$VPNTYPE"
	PressEnter

	ReturnToMainMenu "Update VPN complete ($VPNTYPE)"
}

ScheduleUpdateMenu(){
	ScriptHeader
	ScheduleUpdateMenuHeader
	
	SetVPNClient
	SetVPNProtocol
	SetVPNType
	SetDays
	SetHours
	SetMinutes

	$CONTROLSCRIPT schedule "$VPN_NO" "$VPNPROT" "$CRU_MINUTE" "$CRU_HOUR" "$CRU_DAYNUMBERS" "$VPNTYPE"
	PressEnter

	ReturnToMainMenu "Scheduled VPN update complete ($VPNTYPE)"
}

DeleteScheduleMenu(){
	ScriptHeader
	DeleteScheduleMenuHeader

	SetVPNClient

	$CONTROLSCRIPT cancel "$VPN_NO"
	PressEnter

	ReturnToMainMenu "Delete VPN schedule complete"
}

Addon_Uninstall(){
	printf "Uninstalling $MY_ADDON_NAME has not yet been tested...\\n"
#	printf "Uninstalling $MY_ADDON_NAME..."
#	cd ~
#	rm -f "$LOCAL_REPO" 2>/dev/null
#	printf "Uninstall of $MY_ADDON_NAME completed" 
}

ScriptHeader
MainMenu