phone-backup.sh - What does it do?
=======

The script at hand aims to regularily backup your phone data to a remote location via rsync/ssh. It runs automatically via cronjob, then switches on your data connection of choice (wifi or mobile data), syncs the data to the remote location and turns off the data connection when finished.

But to be honest, the most impressive part is the flashing of the flashlight when the backup starts/ends ;)

Prerequisites
=======

  * Your phone must be rooted
  * You have to install BusyBox from Play store (it contains "crond")
  * Using "crond", you have to set up a cronjob to execute the script at hand. See "Creating the cronjob" below
  * Create a SSH key: ssh-keygen -t rsa -b 4096 -f /path/to/key
  * Create a user on the target system and store the public part of the key in ~/.ssh/authorized_keys file of the target user
    * consider limiting the remote shell to rsync (you may look into "rssh")
  * modify the script to match your setup (paths, user accounts, hosts, keyfiles etc.) - should be pretty straight forward since I commented every important line

Options
=======

  * FLASH_LIGHTS: if set to 1, flash the flashlight once when the backup begins and three times when the backup has finished
  * DATA_CONNECTION: determines the connection to be used for backup. Can be set to "wifi" or "data"
  * ONLY_IF_HOME: if $DATA_CONNECTION is "wifi", execution can be limited to your home wifi (determined by the MAC address of your wifi default gateway)

Getting shell on your phone
=======

  * Possibility 1) Install your Android SSH server of choice, become root
  * Possibility 2) use "adb shell" via USB using the Android SDK Platform Tools
  

Creating the cronjob
=======

Basic information gathered from [1].

    mkdir /data/cronjob
    echo "0 20 * * * /path/to/phone-backup.sh" > /data/crontab/root
    chmod 0700 /path/to/phone-backup.sh
    # it may be neccessary to remount /system to be able to write to it
    mount -o remount,rw /system
    echo "crond -b -c /data/crontab" > /system/etc/init.d/95crond
    chmod 0755 /system/etc/init.d/95crond
    chown root:shell /system/etc/init.d/95crond
    # remount ro, if mounted rw above
    mount -o remount,ro /system

[1] http://stackoverflow.com/questions/16747880/how-to-use-crontab-in-android

Please feel free to fork, contribute, file issues or buy me some flowers.

* Bitcoin: 161DUoRPtDQ896i8M2DRP4gnvNLUfaFLsc
* Namecoin: MzbU4nMuFR8gEpP3zfQs89y8MXKCo1moh3

Cheers, Thomas