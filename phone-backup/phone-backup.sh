#!/system/bin/sh
# Author: Thomas Dalichow, www.thomasdalichow.de
# 
# This script aims to provide a way of syncing data on your Android phone
# to a remote location so the data is not lost when your phone is lost or
# destroyed

FLASHLIGHT_PATH="/sys/devices/i2c-2/2-0033/leds/flashlight/brightness"
PRIVATE_KEY="/data/.ssh/id_rsa"

function flashlight () {
	COUNT=$1
	I=1
	while [[ "$I" -le "$COUNT" ]]; do
		echo 1 > $FLASHLIGHT_PATH
		sleep 0.3
		echo 0 > $FLASHLIGHT_PATH
		sleep 1
		I=$(( $I + 1 ))
	done
	return 0
}

# if set to 1, flash the flashlight once when the backup begins and three
# times when the backup has finished
#
# $FLASHLIGHT_PATH might be different on your version of android, the path
# above has been taken from a HTC One m7 running Cyanogenmod 11, Snapshot M11
#
# if you cannot find the path, just set $FLASH_LIGHTS to 0
FLASH_LIGHTS=1

if [[ "$FLASH_LIGHTS" -eq "1" ]]; then
	flashlight 1
fi

# path where to store the temporary backup files
WORKING_DIR="/storage/emulated/legacy/BACKUP_TMP"

# Directories to backup
DIRECTORIES="/storage/emulated/legacy
/data/data
/data/.ssh
/data/crontab
/data/bin
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
CONNECTION_STATE=$(ping -c 1 -W 1 $TESTHOST >/dev/null)
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
        rsync -rptgoDq --exclude '$WORKING_DIR' --delete $DIRECTORY $WORKING_DIR/
done

# sync data to remote server
rsync -rptzgoDq --delete -e "ssh -i $PRIVATE_KEY" $WORKING_DIR/ $SYNC_USER@$SYNC_HOST:$REMOTE_DIR/

# disable data connection
if [[ "$ALREADY_ENABLED" -eq "0" ]]; then
	su --login --command "svc $SERVICE disable" system
fi

if [[ "$FLASH_LIGHTS" -eq "1" ]]; then
	flashlight 3
fi
