#!/system/bin/sh
# Author: Thomas Dalichow, www.thomasdalichow.de
#
# This script is to be used as a cronjob. I deletes a list of directories
# to prevent the backup from getting too large


DIRECTORIES="/data/data/org.mozilla.firefox/cache
/data/data/org.mozilla.firefox/files
"

for DIRECTORY in $DIRECTORIES; do
	if [[ -d $DIRECTORY ]]; then
		rm -rf $DIRECTORY
	fi
done
