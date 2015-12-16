#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#   AdobeFlashUpdate.sh -- Installs or updates Adobe Flash
#
# SYNOPSIS
#   sudo AdobeFlashUpdate.sh
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.1
#
#   - v.1.0	Steve Miller, 16.12.2015	Used Joe Farage "AdobeReaderUpdate.sh as starting point
#   - v.1.1	Steve Miller, 16.12.2015	Updated to copy echo commands into JSS policy logs
#
####################################################################################################
# Script to download and install Adobe Flash.
# Only works on Intel systems.

dmgfile="flash.dmg"
dmgmount="Flash Player"
volname="Flash"
logfile="/Library/Logs/FlashUpdateScript.log"

# Are we running on Intel?
if [ '`/usr/bin/uname -p`'="i386" -o '`/usr/bin/uname -p`'="x86_64" ]; then
    ## Get OS version and adjust for use with the URL string
    OSvers_URL=$( sw_vers -productVersion )

    ## Set the User Agent string for use with curl
    userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

    # Get latest Flash version online
    latestver=``
    while [ -z "$latestver" ]
    do
    	latestver=`/usr/bin/curl -s http://www.adobe.com/software/flash/about/ | sed -n '/Safari/,/<\/tr/s/[^>]*>\([0-9].*\)<.*/\1/p'`
	done
	
	echo "Latest Version is: $latestver"
	latestvernorm=`echo $ {latestver} `
    # Get the version number of the currently installed Adobe Flash, if any.
    if [ -e "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/" ]; then
		currentinstalledver=`/usr/bin/defaults read "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/Info" CFBundleShortVersionString`
    	echo "Currently installed version is: $currentinstalledver"
    	if [ "${latestver}" != "${currentinstalledver}" ]; then
    		echo "Adobe Flash is current. Exiting"
    		exit 0
    	fi
    else
       currentinstalledver="none"
       echo "Adobe Flash is not installed"
    fi
    
    
    shortver=${latestver:0:2}
    echo "Flash Short version: $shortver"
    url1="http://fpdownload.macromedia.com/get/flashplayer/current/licensing/mac/install_flash_player_${shortver}_osx.dmg"

	#Build URL  
    url=`echo "${url1}"`
    echo "Latest version of the URL is: $url"
    

    # Compare the two versions, if they are different of Flash is not present then download and install the new version.
    if [ "${currentinstalledver}" != "${latestver}" ]; then
        /bin/echo "`date`: Current Flash version: ${currentinstalledver}" >> ${logfile}
        /bin/echo "`date`: Available Flash version: ${latestver}" >> ${logfile}
        /bin/echo "`date`: Downloading newer version." >> ${logfile}
        /usr/bin/curl -s -o /tmp/${dmgfile} ${url}
        /bin/echo "`date`: Mounting installer disk image." >> ${logfile}
        /usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
        /bin/echo "`date`: Installing..." >> ${logfile}
        /usr/sbin/installer -pkg /Volumes/Flash\ Player/Install\ Adobe\ Flash\ Player.app/Contents/Resources/Adobe\ Flash\ Player.pkg -target / > /dev/null
        
        /bin/sleep 10
        /bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
        #/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep ${volname} | awk '{print $1}') -quiet
        /sbin/umount "/Volumes/${dmgmount}"
        /bin/sleep 10
        /bin/echo "`date`: Deleting disk image." >> ${logfile}
        /bin/rm /tmp/${dmgfile}
        
        #Double check to see if the new version got updated
        newlyinstalledver=`/usr/bin/defaults read "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/version" CFBundleShortVersionString`
        if [ "${latestver}" = "${newlyinstalledver}" ]; then
            /bin/echo "SUCCESS: Flash has been updated to version ${newlyinstalledver}"
            /bin/echo "`date`: SUCCESS: Flash has been updated to version ${newlyinstalledver}" >> ${logfile}
        # /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "Adobe Reader Updated" -description "Adobe Reader has been updated." &
        else
            /bin/echo "ERROR: Flash update unsuccessful, version remains at ${currentinstalledver}."
            /bin/echo "`date`: ERROR: Flash update unsuccessful, version remains at ${currentinstalledver}." >> ${logfile}
            /bin/echo "--" >> ${logfile}
            exit 1
        fi
        
    # If Flash is up to date already, just log it and exit.       
    else
        /bin/echo "Flash is already up to date, running ${currentinstalledver}."
        /bin/echo "`date`: Flash is already up to date, running ${currentinstalledver}." >> ${logfile}
        /bin/echo "--" >> ${logfile}
    fi
else
	/bin/echo "`date`: ERROR: This script is for Intel Macs only." >> ${logfile}
fi

exit 0
