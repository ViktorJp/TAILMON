#!/bin/sh

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="0.0.1"
apppath="/jffs/scripts/tailmon.sh"                                   # Static path to the app
config="/jffs/addons/tailmon.d/tailmon.cfg"                          # Static path to the config file
tsinstalled=0
keepalive=0
timerloop=60
logsize=2000
amtmemailsuccess=0
amtmemailfailure=0
precmd=""
args="--tun=userspace-networking --state=/opt/var/tailscaled.state"
preargs="nohup"
routes="192.168.50.0/24"

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CDkGray="\e[1;90m"
InvDkGray="\e[1;100m"
InvLtGray="\e[1;47m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
InvWhite="\e[1;107m"
CClear="\e[0m"

# -------------------------------------------------------------------------------------------------------------------------
# Promptyn is a simple function that accepts y/n input

promptyn() 
{   # No defaults, just y or n
  while true; do
    read -p "$1" -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity

preparebar() 
{
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

progressbaroverride() 
{
  insertspc=" "
  bypasswancheck=0

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    if [ ! -z $7 ] && [ $1 -ge $7 ]; then
      barch=$(($7*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    else
      barch=$(($1*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    fi

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      printf "  ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%${CClear} [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]\r${CClear}" "$barchars" "$barspaces"
    fi
  fi

  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
      	  3) editargs;;
          [Cc]) vsetup;;
          [Dd]) tsdown;;
          [Ee]) logoNMexit; echo -e "${CClear}\n"; exit 0;;
          [Ii]) installts;;
          [Kk]) vconfig;;
          [Ll]) vlogs;;
          [Mm]) timerloopconfig;;
          [Ss]) startts;;
          [Tt]) stopts;;
          [Uu]) tsup;;
          [Vv]) editroutes;;
          [Xx]) uninstallts;;
          *) timer=$timerloop;;
      esac
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Install script

installts () {

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Tailscale                                                                     ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This installer will download and install Tailscale from the Entware respository."
  echo -e "${InvGreen} ${CClear} It will also check for any prerequisites before install commences."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Install Tailscale?"
  if promptyn "[y/n]: "
    then
      if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
        echo ""
        echo -e "\nUpdating Entware Packages..."
        echo ""
        opkg update
        echo ""
        echo -e "Installing Tailscale Package(s)..."
        echo ""
        opkg install tailscale
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
      else
        clear
        echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
        echo -e "Please install Entware using the AMTM utility before proceeding..."
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exit 1
      fi
  fi
  resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Uninstall script

uninstallts () {

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Uninstall Tailscale                                                                   ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This uninstaller utility will remove Tailscale Entware packages from your router"
  echo -e "${InvGreen} ${CClear} along with all files and modifications made to Tailscale."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Uninstall Tailscale?"
  if promptyn "[y/n]: "
    then
      if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
        echo ""
        echo -e "\nUpdating Entware Packages..."
        echo ""
        opkg update
        echo ""
        echo -e "Uninstalling Tailscale Package(s)..."
        echo ""
        opkg remove tailscale
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
      else
        clear
        echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
        echo -e "Please install Entware using the AMTM utility before proceeding..."
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exit 1
      fi
  fi
  resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# start service script

startts () {

      printf "\33[2K\r"
      printf "${CGreen}\r[Starting Tailscale Service]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:"
      echo ""
      /opt/etc/init.d/S06tailscaled start
      echo ""
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# stop service script

stopts () {

      printf "\33[2K\r"
      printf "${CGreen}\r[Stopping Tailscale Service]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:"
      echo ""
      /opt/etc/init.d/S06tailscaled stop
      echo ""
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Tailscale connection up

tsup () {

      printf "\33[2K\r"
      printf "${CGreen}\r[Activating Tailscale Connection]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:${CClear}"
      echo ""
       if [ -z $routes ]; then
        echo "Executing: tailscale up"
        echo ""
        tailscale up
      else
        echo "Executing: tailscale up --accept-routes --advertise-routes=$routes"
        echo ""
        tailscale up --accept-routes --advertise-routes=$routes
      fi
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Tailscale connection down

tsdown () {

      printf "\33[2K\r"
      printf "${CGreen}\r[Deactiving Tailscale Connection]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:${CClear}"
      echo ""
      echo "Executing: tailscale down"
      echo ""
      tailscale down
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# timerloopconfig lets you configure how long you want the timer cycle to last between tailscale checks

timerloopconfig()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Timer Loop Configuration                                                              ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate how long the timer cycle should take between Tailscale Service and.${CClear}"
  echo -e "${InvGreen} ${CClear} Connection checks."
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = 60 seconds)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$timerloop sec${CClear}"
  echo ""
  read -p "Please enter value (1-999)? (e=Exit): " EnterTimerLoop
  case $EnterTimerLoop in
    [1-9]) 
      timerloop=$EnterTimerLoop
      saveconfig
      timer=$timerloop
    ;;

    [1-9][0-9])
      timerloop=$EnterTimerLoop
      saveconfig
      timer=$timerloop
    ;;

    [1-9][0-9][0-9])
      timerloop=$EnterTimerLoop
      saveconfig
      timer=$timerloop
    ;;

    *)
      echo ""
      echo -e "${CClear}[Exiting]"
      timer=$timerloop
      break
    ;;
  esac

done

}

# -------------------------------------------------------------------------------------------------------------------------
# vsetup provide a menu interface to allow for initial component installs, uninstall, etc.

vsetup()
{

while true; do

  clear # Initial Setup
  if [ ! -f $config ]; then # Write /jffs/addons/tailmon.d/tailmon.cfg
    saveconfig
  fi

  echo -e "${InvGreen} ${InvDkGray}${CWhite} TAILMON Main Setup and Configuration Menu                                             ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to perform high level${CClear}"
  echo -e "${InvGreen} ${CClear} actions in the management of the TAILMON script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Custom configuration options for TAILMON${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Force reinstall Entware dependencies${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Check for latest updates${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Uninstall TAILMON${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-4, e=Exit): " SelectSlot
    case $SelectSlot in
      1) # Check for existence of entware, and if so proceed and install the timeout package, then run tailmon -config
        clear
        if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ]; then
          vconfig
        else
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Dependencies                                                                  ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Missing dependencies required by TAILMON will be installed during this process."         
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          echo -e "TAILMON has some dependencies in order to function correctly, namely, CoreUtils-Timeout"
          echo -e "and the Screen utility. These utilities require you to have Entware already installed"
          echo -e "using the AMTM tool. If Entware is present, the Timeout and Screen utilities will"
          echo -e "automatically be downloaded and installed during this process."
          echo ""
          echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
          echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
          echo ""
          echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
          echo -e "directly on the router itself, instead of running your commands or a script from a network-"
          echo -e "attached SSH client. This can provide greater stability due to it running on the router"
          echo -e "itself."
          echo ""
          [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
          echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
          echo ""
          echo -e "Ready to install?"
          if promptyn "[y/n]: "
            then
              if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                echo ""
                echo -e "\n${CClear}Updating Entware Packages..."
                echo ""
                opkg update
                echo ""
                echo -e "Installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package...${CClear}"
                echo ""
                opkg install coreutils-timeout
                echo ""
                echo -e "Installing Entware ${CGreen}Screen${CClear} Package...${CClear}"
                echo ""
                opkg install screen
                echo ""
                echo -e "Install completed..."
                echo ""
                read -rsp $'Press any key to continue...\n' -n1 key
                echo ""
                echo -e "Executing Configuration Utility..."
                sleep 2
                vconfig
              else
                clear
                echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                echo -e "Please install Entware using the AMTM utility before proceeding..."
                echo ""
                read -rsp $'Press any key to continue...\n' -n1 key
              fi
            else
              echo ""
              echo -e "\nExecuting Configuration Utility..."
              sleep 2
              vconfig
          fi
        fi
      ;;

      2) # Force re-install the CoreUtils timeout/screen package
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Re-install Dependencies                                                               ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Missing dependencies required by TAILMON will be re-installed during this process."         
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "Would you like to re-install the CoreUtils-Timeout and the Screen utility? These"
        echo -e "utilities require you to have Entware already installed using the AMTM tool. If Entware"
        echo -e "is present, the Timeout and Screen utilities will be uninstalled, downloaded and re-"
        echo -e "installed during this setup process..."
        echo ""
        echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
        echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router"
        echo -e "model."
        echo ""
        echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
        echo -e "directly on the router itself, instead of running your commands or a script from a"
        echo -e "network-attached SSH client. This can provide greater stability due to it running on"
        echo -e "the router itself."
        echo ""
        [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
        echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
        echo ""
        echo -e "Force Re-install?"
        if promptyn "[y/n]: "
          then
            if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
              echo ""
              echo -e "\nUpdating Entware Packages..."
              echo ""
              opkg update
              echo ""
              echo -e "Force Re-installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package..."
              echo ""
              opkg install --force-reinstall coreutils-timeout
              echo ""
              echo -e "Force Re-installing Entware ${CGreen}Screen${CClear} Package..."
              echo ""
              opkg install --force-reinstall screen
              echo ""
              echo -e "Re-install completed..."
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
            else
              clear
              echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
              echo -e "Please install Entware using the AMTM utility before proceeding..."
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
            fi
        fi
      ;;
      3) vupdate;;
      4) vuninstall;;
      [Ee])
            echo ""
            timer=$timerloop
            break;;
    esac
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig is a function that provides a UI to choose various options for tailmon

vconfig() 
{

# Grab the TAILMON config file and read it in
if [ -f $config ]; then
  source $config
else
  clear
  echo -e "${CRed}ERROR: TAILMON is not configured.  Please run 'tailmon.sh -setup' first."
  echo ""
  echo -e "${CClear}"
  exit 1
fi

while true; do

  if [ $keepalive -eq 0 ]; then
    keepalivedisp="No"
  else
    keepalivedisp="Yes"
  fi

  if [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "0" ]; then
    amtmemailsuccfaildisp="Disabled"
  elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "0" ]; then
    amtmemailsuccfaildisp="Success"
  elif [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "1" ]; then
    amtmemailsuccfaildisp="Failure"
  elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "1" ]; then
    amtmemailsuccfaildisp="Success, Failure"
  else
    amtmemailsuccfaildisp="Disabled"
  fi

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} TAILMON Configuration Option                                                          ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to modify certain${CClear}"
  echo -e "${InvGreen} ${CClear} customizable parameters that affect the operation of this script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Keep Tailscale Service Alive                 : ${CGreen}$keepalivedisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Timer Check Loop Interval                    : ${CGreen}${timerloop}sec"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Custom Event Log size (rows)                 : ${CGreen}$logsize"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : AMTM Email Notifications on Success/Failure  : ${CGreen}$amtmemailsuccfaildisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-4, e=Exit): " SelectSlot
    case $SelectSlot in
      1)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Keep Tailscale Service Alive                                                          ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate if you want TAILMON to check the status of the Tailscale Service${CClear}"
        echo -e "${InvGreen} ${CClear} and restart it if necessary? While Tailscale overall is fairly stable, there are${CClear}"
        echo -e "${InvGreen} ${CClear} instances where the service with terminate."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = Yes)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$keepalivedisp${CClear}"
        echo ""
        echo -e "Keep Alive?"
        if promptyn "[y/n]: "
          then
            keepalive=1
          else
            keepalive=0
        fi
        saveconfig
      ;;

      2) timerloopconfig
      ;;

      3) 
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom Event Log Size                                                                 ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below how large you would like your Event Log to grow. I'm a poet${CClear}"
        echo -e "${InvGreen} ${CClear} and didn't even know it. By default, with 2000 rows, you will have many months of${CClear}"
        echo -e "${InvGreen} ${CClear} Event Log data."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, max number of rows is 9999. (Default = 2000)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$logsize${CClear}"
        echo ""
        read -p "Please enter Log Size (in rows)? (0-9999, e=Exit): " NEWLOGSIZE

          if [ "$NEWLOGSIZE" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          elif [ $NEWLOGSIZE -ge 0 ] && [ $NEWLOGSIZE -le 9999 ]; then
            logsize=$NEWLOGSIZE
            saveconfig
          else
            logsize=2000
            saveconfig
          fi
      ;;

      4)
        amtmevents
        source $config
      ;;
      
      [Ee]) echo -e "${CClear}\n[Exiting]"; sleep 2; resettimer=1; break ;;

    esac
done
}

# -------------------------------------------------------------------------------------------------------------------------
# saveconfig saves the tailmon.cfg file after every major change, and applies that to the script on the fly

saveconfig()
{

   { echo 'keepalive='$keepalive
     echo 'timerloop='$timerloop
     echo 'logsize='$logsize
     echo 'amtmemailsuccess='$amtmemailsuccess
     echo 'amtmemailfailure='$amtmemailfailure
     echo 'precmd="'"$precmd"'"'
     echo 'args="'"$args"'"'
     echo 'preargs="'"$preargs"'"'
     echo 'routes="'"$routes"'"'
   } > $config

}

# -------------------------------------------------------------------------------------------------------------------------

# Check and see if any commandline option is being used
if [ $# -eq 0 ]
  then
    clear
    exec sh /jffs/scripts/tailmon.sh -noswitch
    exit 0
fi

# Check and see if an invalid commandline option is being used
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-setup" ] || [ "$1" == "-bw" ] || [ "$1" == "-noswitch" ] || [ "$1" == "-screen" ] || [ "$1" == "-now" ] 
  then
    clear
  else
    clear
    echo ""
    echo "TAILMON v$version"
    echo ""
    echo "Exiting due to invalid commandline options!"
    echo "(run 'tailmon.sh -h' for help)"
    echo ""
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the help option is being called
if [ "$1" == "-h" ] || [ "$1" == "-help" ]
  then
  clear
  echo ""
  echo "TAILMON v$version Commandline Option Usage:"
  echo ""
  echo "vpnmon-r3 -h | -help"
  echo "vpnmon-r3 -setup"
  echo "vpnmon-r3 -bw"
  echo "vpnmon-r3 -screen"
  echo "vpnmon-r3 -screen -now"
  echo ""
  echo " -h | -help (this output)"
  echo " -setup (displays the setup menu)"
  echo " -bw (runs tailmon in monochrome mode)"
  echo " -screen (runs tailmon in screen background)"
  echo " -screen -now (runs tailmon in screen background immediately)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if a second command is being passed to remove color
if [ "$1" == "-bw" ] || [ "$2" == "-bw" ]
  then
    blackwhite
fi

# Check to see if the -now parameter is being called to bypass the screen timer
if [ "$2" == "-now" ]
  then
    bypassscreentimer=1
fi

# Check to see if the setup option is being called
if [ "$1" == "-setup" ]
  then
    #logoNM
    vsetup
    exit 0
fi

# Check to see if the screen option is being called and run operations normally using the screen utility
if [ "$1" == "-screen" ]
  then
    screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
    sleep 1
    ScreenSess=$(screen -ls | grep "tailmon" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        if [ "$bypassscreentimer" == "1" ]; then
          screen -dmS "tailmon" $apppath -noswitch
          sleep 1
          screen -r tailmon
        else
          clear
          echo -e "${CClear}Executing ${CGreen}TAILMON v$version${CClear} using the SCREEN utility..."
          echo ""
          echo -e "${CClear}IMPORTANT:"
          echo -e "${CClear}In order to keep TAILMON running in the background,"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          screen -dmS "tailmon" $apppath -noswitch
          sleep 5
          screen -r tailmon
          exit 0
        fi
      else
        if [ "$bypassscreentimer" == "1" ]; then
          sleep 1   
        else
          clear
          echo -e "${CClear}Connecting to existing ${CGreen}TAILMON v$version${CClear} SCREEN session...${CClear}"
          echo ""
          echo -e "${CClear}IMPORTANT:${CClear}"
          echo -e "${CClear}In order to keep TAILMON running in the background,${CClear}"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          echo -e "${CClear}Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          spinner 5
        fi
      fi
    screen -dr $ScreenSess
    exit 0
fi

# Check to see if the noswitch  option is being called
if [ "$1" == "-noswitch" ]
  then
    clear #last switch before the main program starts

    if [ ! -f $cfgpath ] && [ ! -f "/opt/bin/timeout" ] && [ ! -f "/opt/sbin/screen" ]; then
      echo -e "${CRed}ERROR: TAILMON is not configured.  Please run 'vpnmon-r3 -setup' first.${CClear}"
      echo ""
      exit 0
    fi
fi

# -------------------------------------------------------------------------------------------------------------------------
# Begin TAILMON Main Loop
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

# Create the necessary folder/file structure for VPNMON-R3 under /jffs/addons
if [ ! -d "/jffs/addons/tailmon.d" ]; then
  mkdir -p "/jffs/addons/tailmon.d"
fi

# Check for and add an alias for TAILMON
if ! grep -F "sh /jffs/scripts/tailmon.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
  echo "alias tailmon=\"sh /jffs/scripts/tailmon.sh\" # added by tailmon" >> /jffs/configs/profile.add
fi

while true; do

  # Grab the TAILMON config file and read it in
  if [ -f $config ]; then
    source $config
  else
    clear
    echo -e "${CRed}ERROR: TAILMON is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "${CClear}"
    exit 1
  fi 
  
  if [ -f "/opt/bin/tailscale" ]; then
  	tsinstalled=1
    clear
    
    if [ $keepalive -eq 1 ]; then
      keepalivedisp="Yes"
    else
      keepalivedisp="No"
    fi
  
    tzone=$(date +%Z)
    tzonechars=$(echo ${#tzone})

    if [ $tzonechars = 1 ]; then tzspaces="        ";
    elif [ $tzonechars = 2 ]; then tzspaces="       ";
    elif [ $tzonechars = 3 ]; then tzspaces="      ";
    elif [ $tzonechars = 4 ]; then tzspaces="     ";
    elif [ $tzonechars = 5 ]; then tzspaces="    "; fi

    #Display VPNMON-R3 client header
    echo -en "${InvGreen} ${InvDkGray} TAILMON - v"
    printf "%-8s" $version
    echo -e "                           ${CWhite}Operations Menu ${InvDkGray}            $tzspaces$(date) ${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(I)${CClear}nstall / ${CGreen}(X)${CClear}Uninstall Tailscale                   ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(S)${CClear}tart / S${CGreen}(T)${CClear}op Tailscale Service                   ${InvGreen} ${CClear} ${CGreen}(E)${CClear}dit PRECMD / ARGS / PREARGS${CClear}"
    echo -e "${InvGreen} ${CClear} Tailscale Connection ${CGreen}(U)${CClear}p / ${CGreen}(D)${CClear}own                   ${InvGreen} ${CClear} Edit Ad${CGreen}(V)${CClear}ertised Routes${CClear}"
    echo -e "${InvGreen} ${CClear}                                                      ${InvGreen} ${CClear} ${CGreen}(K)${CClear}eep Tailscale Service Alive: ${CGreen}$keepalivedisp${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(A)${CClear}MTM Email Notifications: $amtmdisp                         ${InvGreen} ${CClear} Ti${CGreen}(M)${CClear}er Check Loop Interval: ${CGreen}${timerloop}sec${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
    echo -e "${InvDkGray}Tailscale Service:                                                                                             ${CClear}"
    /opt/etc/init.d/S06tailscaled check
    tsservice=$?
    
    echo ""
    echo -e "${InvDkGray}Tailscale Connection Status:                                                                                   ${CClear}"
    tailscale status
    echo ""
    echo -e "${InvDkGray}Tailscale Options:                                                                                             ${CClear}"
    echo -e "${CWhite}PRECMD: ${CGreen}$precmd"
    echo -e "${CWhite}ARGS: ${CGreen}$args"
    echo -e "${CWhite}PREARGS: ${CGreen}$preargs"
    echo -e "${CWhite}ROUTES: ${CGreen}$routes"
    echo ""
    #read -rsp $'Press any key to continue...\n' -n1 key
  else
    echo -e "Tailscale is not installed"
    tsinstalled=0
  fi
  
  if [ $tsinstalled -eq 1 ] && [ $keepalive -eq 1 ]; then
    if [ $tsservice -gt 0 ]; then
      printf "\33[2K\r"
      printf "${CGreen}\r[Tailscale Service appears dead]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:"
      echo ""
      /opt/etc/init.d/S06tailscaled start
      echo ""
      
      if [ -z $routes ]; then
        echo "Executing: tailscale up"
        echo ""
        tailscale up
      else
        echo "Executing: tailscale up --accept-routes --advertise-routes=$routes"
        echo ""
        tailscale up --accept-routes --advertise-routes=$routes
      fi

      sleep 3
      resettimer=1
    fi
  fi

  #display a standard timer
  if [ "$resettimer" == "0" ]; then
    timer=0
    while [ $timer -ne $timerloop ]
      do
        timer=$(($timer+1))
        preparebar 46 "|"
        progressbaroverride $timer $timerloop "" "s" "Standard"
        if [ "$resettimer" == "1" ]; then timer=$timerloop; fi
      done
  fi
  resettimer=0
  
done

exit 0
