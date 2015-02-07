#!/system/bin/sh
# Author: Thomas Dalichow, www.thomasdalichow.de
# 
# This script aims to provide a way of syncing data on your Android phone
# to a remote location so the data is not lost when your phone is lost or
# destroyed

# Android Key Events: see http://developer.android.com/reference/android/view/KeyEvent.html
# Android Wake Locks: see http://stackoverflow.com/questions/5780280/how-can-i-see-which-wakelocks-are-active

FLASHLIGHT_PATH="/sys/class/leds"
PRIVATE_KEY="/data/data/.ssh/id_rsa"
PING=/system/xbin/ping
SSH=/system/bin/ssh
RSYNC=/system/xbin/rsync

function manage_led () {
	LED=$1
	ACTION=$2
	BLINK=$3
	FLASHLIGHT_PATH_LED="$FLASHLIGHT_PATH/$LED"
	if [[ "$ACTION" == "enable" ]]; then
		STATE=1	
	elif [[ "$ACTION" == "disable" ]]; then
		STATE=0
	else
		exit 1
	fi

	if [[ "$BLINK" == "blink" ]]; then
		BLINKING=1
	else
		BLINKING=0
	fi

	echo $STATE > $FLASHLIGHT_PATH_LED/brightness

	if [[ "$BLINKING" -eq "1" && $LED != "flashlight" ]]; then
		echo $STATE > $FLASHLIGHT_PATH_LED/blink
	fi

	return 0
}

function flash_led () {
	LED=$1
	COUNT=$2
	I=1

	while [[ "$I" -le "$COUNT" ]]; do
		manage_led $LED enable
		sleep 0.3
		manage_led $LED disable
		sleep 1
		I=$(( $I + 1 ))
	done
}

manage_led amber enable
manage_led green enable blink

# if set to 1, flash the flashlight once when the backup begins and three
# times when the backup has finished
#
# $FLASHLIGHT_PATH might be different on your version of android, the path
# above has been taken from a HTC One m7 running Cyanogenmod 11, Snapshot M11
#
# if you cannot find the path, just set $FLASH_LIGHTS to 0
FLASH_LIGHTS=1

if [[ "$FLASH_LIGHTS" -eq "1" ]]; then
	flash_led flashlight 1
fi

# path where to store the temporary backup files
WORKING_DIR="/storage/emulated/legacy/BACKUP_TMP"

# Directories to backup
DIRECTORIES="/storage/emulated/legacy
/data/data
"

# host to connect via ssh
SYNC_HOST="test.example.com"

# ssh user to use when connecting to $SYNC_HOST
SYNC_USER="testuser"

# target directory on $SYNC_HOST
REMOTE_DIR="/remote/test"

# hostname that is beeing sent a "ping" to check whether we have a working
# network connection
TESTHOST="google-public-dns-a.google.com"

# mac address of your wifi router at home
HOME_MAC="01:02:03:04:05:06"

# only make backups when at $HOME
ONLY_IF_HOME=0

# if data connections is already enabled, connection won't be establised
# nor disabled after backup
ALREADY_ENABLED="0"

# which data connection to use
# may be "wlan" or "data"
DATA_CONNECTION="wifi"

# define which network interface / connections is to be used
# WiFi: wlan0
# Mobile data connection: rmnet_usb0
# (beware, this has only been tested on Android 4.4 so your connections might
# appear with a different interface name
if [[ "$DATA_CONNECTION" == "wifi" ]]; then
        INTERFACE="wlan0"
        SERVICE="wifi"
elif [[ "$DATA_CONNECTION" == "data" ]]; then
        INTERFACE="rmnet_usb0"
        SERVICE="data"
fi

# check whether connection is already up
# 0 = successful grep, so interface is UP
LINK_STATE=$(/system/bin/ip link show $INTERFACE  | grep -q "state UP")
if [[ ! $LINK_STATE ]]; then
        # connection is not up so enable it
        su --login --command "svc $SERVICE enable" system

	TRY_SECONDS=15
	SECONDS=1
        while [[ "$SECONDS" -le "$TRY_SECONDS" ]]; do
                LINK_STATE=$(/system/bin/ip link show $INTERFACE  | grep -q "state UP")
                if [[ $LINK_STATE ]]; then
                        break
                fi
                sleep 1
		SECONDS=$(( $SECONDS + 1 ))
        done
else
	ALREADY_ENABLED="1"
fi

# Give me a ping, Vasili. One ping only, please.
CONNECTION_STATE=$($PING -I $INTERFACE -c 1 -W 1 $TESTHOST >/dev/null)
if [[ "$CONNECTION_STATE" -ne "0" ]]; then
	# no ping possible - exit
	exit 1
fi

# if not at home, do not start backup
if [[ "$DATA_CONNECTION" == "wifi" && "$ONLY_IF_HOME" -eq "1" ]]; then
        # get default gateway address
        GATEWAY_IP=$(ip route | awk '/^default via/ {print $3}')
        GATEWAY_MAC=$(arp $GATEWAY_IP | awk {'print $4'})
        if [[ "$GATEWAY_MAC" != "$HOME_MAC" ]]; then
                exit 1
        fi
fi


# let's backup the data then \o/
if [[ ! -d $WORKING_DIR ]]; then
        mkdir $WORKING_DIR
fi

for DIRECTORY in $DIRECTORIES; do
        $RSYNC -rptgoDq --exclude '$WORKING_DIR' --delete $DIRECTORY $WORKING_DIR/
done

# sync data to remote server
$RSYNC -rptzgoDq --delete -e "$SSH -i $PRIVATE_KEY" $WORKING_DIR/ $SYNC_USER@$SYNC_HOST:$REMOTE_DIR/

# disable data connection
if [[ "$ALREADY_ENABLED" -eq "0" ]]; then
	su --login --command "svc $SERVICE disable" system
fi

manage_led amber disable
manage_led green disable blink

if [[ "$FLASH_LIGHTS" -eq "1" ]]; then
	flash_led flashlight 3
fi
