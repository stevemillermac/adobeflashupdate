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
#   Version: 1.5
#
#   - v.1.0 Steve Miller, 16.12.2015:   Used Joe Farage "AdobeReaderUpdate.sh as starting point
#   - v.1.1 Steve Miller, 16.12.2015:   Updated to copy echo commands into JSS policy logs
#   - v.1.2 Steve Miller, 21.12.2015:   Updated umount command to use hdiutil. 10.9 issues previous command
#   - v.1.3 Steve Miller, 13.05.2016:   Updated to fix line 45 for change on website.
#   - v.1.4 Steve Miller, 16.12.2016:   Reworked to utilize code from Luis Lugo in Reader script.
#   - v.1.5 Steve Miller, 11.01.2017:   Change to Adobe download URL format
#
####################################################################################################
# Script to download and install Adobe Flash.
# Only works on Intel systems.

# Setting variables
dmgfile="flash.dmg"

# Echo function
echoFunc () {
    # Date and Time function for the log file
    fDateTime () { echo $(date +"%a %b %d %T"); }

    # Title for beginning of line in log file
    Title="InstallLatestAdobeFlash:"

    # Header string function
    fHeader () { echo $(fDateTime) $(hostname) $Title; }

    # Check for the log file
    if [ -e "/Library/Logs/AdobeFlashUpdateScript.log" ]; then
        echo $(fHeader) "$1" >> "/Library/Logs/AdobeFlashUpdateScript.log"
    else
        cat > "/Library/Logs/AdobeFlashUpdateScript.log"
        if [ -e "/Library/Logs/AdobeFlashUpdateScript.log" ]; then
            echo $(fHeader) "$1" >> "/Library/Logs/AdobeFlashUpdateScript.log"
        else
            echo "Failed to create log file, writing to JAMF log"
            echo $(fHeader) "$1" >> "/var/log/jamf.log"
        fi
    fi

    # Echo out
    echo $(fDateTime) ": $1"
}

# Exit function
# Exit code examples: http://www.tldp.org/LDP/abs/html/exitcodes.html
exitFunc () {
    case $1 in
        0) exitCode="0 - SUCCESS: Adobe Flash up to date with version $2";;
        3) exitCode="3 - INFO: Adobe Flash NOT installed!";;
        4) exitCode="4 - ERROR: Adobe Flash update unsuccessful, version remains at $2";;
        6) exitCode="6 - ERROR: Not an Intel-based Mac.";;
        *) exitCode="$1";;
    esac
    echoFunc "Exit code: $exitCode"
    echoFunc "======================== Script Complete ========================"
    exit $1
}

echoFunc ""
echoFunc "======================== Starting Script ========================"


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
    	latestver=`/usr/bin/curl -s http://www.adobe.com/software/flash/about/ | sed -n '/Firefox, Safari - NPAPI/,/<\/tr/s/[^>]*>\([0-9].*\)<.*/\1/p'`
	done
	
	echoFunc "Latest Adobe Flash Version is: ${latestver}"
	latestvernorm=`echo $ {latestver} `
    # Get the version number of the currently-installed Adobe Flash, if any.
    if [ -e "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/" ]; then
		currentinstalledapp="Adobe Flash"
		currentinstalledver=`/usr/bin/defaults read "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/Info" CFBundleShortVersionString`
    	echoFunc "Currently installed version is: ${currentinstalledver}"
    	if [ "${latestvernorm}" = "${currentinstalledver}" ]; then
    		exitFunc 0 "${currentinstalledapp} ${currentinstalledver}"
    	fi
    else
        currentinstalledapp="Adobe Flash"
        echoFunc "${currentinstalledapp} is not installed"
    fi
    
	#Build URL
	shortver=${latestver:0:2}
    url1="https://fpdownload.adobe.com/get/flashplayer/pdc/"${latestver}"/install_flash_player_osx.dmg"
    url2=""
    url=`echo "${url1}${url2}"`
    
    
    # Compare the two versions, if they are different of Flash is not present then download and install the new version.
    if [ "${currentinstalledver}" != "${latestver}" ]; then
        echoFunc "Versions differ as following"
        echoFunc "Latest Adobe Flash Version is: ${latestver}"
        echoFunc "Currently installed version is: ${currentinstalledver}"
        echoFunc "Latest version of the URL is: $url"
        echoFunc "Downloading newer version."
        curl -s -o /tmp/${dmgfile} ${url}
        case $? in
            0)
                echoFunc "Checking if the file exists after downloading."
                if [ -e "/tmp/${dmgfile}" ]; then
                    readerFileSize=$(du -k "/tmp/${dmgfile}" | cut -f 1)
                    echoFunc "Downloaded File Size: $readerFileSize kb"
                else
                    echoFunc "File NOT downloaded!"
                    exitFunc 3 "${currentinstalledapp} ${currentinstalledver}"
                fi
                echoFunc "Mounting installer disk image."
                hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
                echoFunc "Installing..."
        		installer -pkg /Volumes/Flash\ Player/Install\ Adobe\ Flash\ Player.app/Contents/Resources/Adobe\ Flash\ Player.pkg -target / > /dev/null
        
        		#Unmount DMG and deleting tmp files
				sleep 10
				mntpoint=`diskutil list | grep Flash | awk '{print $7}' `
                #echoFunc "The mount point is ${mntpoint}"
				echoFunc "Unmounting installer disk image."
                umount "/Volumes/Flash Player"
                #hdiutil detach -force -quiet "${mntpoint}"
                sleep 10
                echoFunc "Deleting disk image."
                rm /tmp/${dmgfile}

        #Double check to see if the new version got updated
        if [ -e "/Library/Internet Plug-Ins/Flash Player.plugin" ]; then
	        newlyinstalledver=`/usr/bin/defaults read "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/Info" CFBundleShortVersionString`
			if [ "${latestver}" = "${newlyinstalledver}" ]; then
            	echoFunc "SUCCESS: Flash has been updated to version ${newlyinstalledver}, issuing JAMF recon command"
            	jamf recon
			fi
            exitFunc 0 "${newlyinstalledver}"
        fi
    ;;
	*)
		echoFunc "Curl function failed on alternate download! Error: $?. Review error codes here: https://curl.haxx.se/libcurl/c/libcurl-errors.html"
		exitFunc 4 "${currentinstalledapp} ${currentinstalledver}"
	;;
	esac
else
           
        # If Flash is up to date already, just log it and exit.
        exitFunc 0 "${currentinstalledapp} ${currentinstalledver}"
    fi
else
    # This script is for Intel Macs only.
    exitFunc 6
fi
