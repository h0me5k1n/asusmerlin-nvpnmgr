#!/bin/sh

source /usr/sbin/helper.sh

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
# load standard variables
source "$SCRIPTPATH/addon_vars"

# Does the firmware support addons?
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]
then
    logger "$MY_ADDON_NAME addon" "This firmware does not support addons!"
    exit 5
fi

# Obtain the first available mount point in $am_webui_page
am_get_webui_page /jffs/addons/$MY_ADDON_NAME/$MY_ADDON_PAGE

if [ "$am_webui_page" = "none" ]
then
    logger "$MY_ADDON_NAME addon" "Unable to install $MY_ADDON_PAGE"
    exit 5
fi
logger "$MY_ADDON_NAME addon" "Mounting $MY_ADDON_PAGE as $am_webui_page"

# Copy custom page
cp /jffs/addons/$MY_ADDON_NAME/$MY_ADDON_PAGE /www/user/$am_webui_page

# Copy menuTree (if no other script has done it yet) so we can modify it
if [ ! -f /tmp/menuTree.js ]
then
    cp /www/require/modules/menuTree.js /tmp/
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

# Insert link at the end of the Tools menu.  Match partial string, since tabname can change between builds (if using an AS tag)
sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"$MY_ADDON_TAB\"}," /tmp/menuTree.js

# sed and binding mounts don't work well together, so remount modified file
umount /www/require/modules/menuTree.js && mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js