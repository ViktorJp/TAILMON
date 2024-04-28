#!/bin/sh

# TAILMON (TAILMON.SH) is an all-in-one script that is optimized to install, maintain and monitor a Tailscale service and
# connection from your Asus-Merlin FW router. It provides the basic steps needed to install and implement a successful
# connection to your tailnet. It allows for 2 different modes of operation: Kernel and Userspace modes. Depending on your
# needs, you can also enable exit node and subnet route advertisements. Separately, TAILMON functions as a Tailscale
# monitor application that will sit in the background (using the -screen utility), and will restart the Tailscale service
# should it happen to go down. Many thanks to: @jksmurf, @ColinTaylor, @Aiadi, and @kuki68ster for all their help, input
# and testing of this script!

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="0.0.8"
beta=0
apppath="/jffs/scripts/tailmon.sh"                                   # Static path to the app
config="/jffs/addons/tailmon.d/tailmon.cfg"                          # Static path to the config file
dlverpath="/jffs/addons/tailmon.d/version.txt"                       # Static path to the version file
logfile="/jffs/addons/tailmon.d/tailmon.log"                         # Static path to the log
tsinstalled=0
keepalive=0
timerloop=60
logsize=2000
amtmemailsuccess=0
amtmemailfailure=0
exitnode=0
advroutes=1
persistentsettings=0
tsoperatingmode="Userspace"
precmd=""
args="--tun=userspace-networking --state=/opt/var/tailscaled.state"
preargs="nohup"
routes="$(nvram get lan_ipaddr | cut -d"." -f1-3).0/24"

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
          [Cc]) vsetup;;
          [Dd]) tsdown;;
          [Ee]) echo -e "${CClear}\n"; exit 0;;
          [Ii]) installts;;
          [Kk]) vconfig;;
          [Ll]) vlogs;;
          [Mm]) timerloopconfig;;
          [Pp]) edittsoptions;;
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
# Initial setup menu

initialsetup() 
{

    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} TAILMON Initial Setup                                                                 ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} TAILMON has not been configured yet, and Tailscale will need to be installed and${CClear}"
    echo -e "${InvGreen} ${CClear} configured. You can choose between 'Express Install' and 'Advanced Install'.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} 1) Express Install will automatically download and install Tailscale, choosing the${CClear}"
    echo -e "${InvGreen} ${CClear} 'Userspace' mode of operation and configures it to advertise routes of your local${CClear}"
    echo -e "${InvGreen} ${CClear} subnet by default. A URL prompt will appear which will require you to copy this link"
    echo -e "${InvGreen} ${CClear} into your browser to connect this device to your tailnet."
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} 2) Advanced Install will launch the TAILMON Setup/Configuration Menu, and allows${CClear}"
    echo -e "${InvGreen} ${CClear} you to manually choose your preferred settings, such as 'Kernel' vs. 'Userspace'${CClear}"
    echo -e "${InvGreen} ${CClear} mode, and letting you pick the exit node option along with additional subnets."
    echo -e "${InvGreen} ${CClear}"    
    echo -e "${InvGreen} ${CClear} Before starting, please familiarize yourself with how Tailscale works. Please use${CClear}"
    echo -e "${InvGreen} ${CClear} @ColinTaylor's Wiki available here:${CClear}"
    echo -e "${InvGreen} ${CClear} https://github.com/RMerl/asuswrt-merlin.ng/wiki/Installing-Tailscale-through-Entware${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} It is also advised to have an account set and ready to go on https://tailscale.com${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    read -p "Please select? (1=Express Install, 2=Advanced Install, e=Exit): " SelectSetup
      case $SelectSetup in
        1) 
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON Express Install initiated." >> $logfile
        expressinstall;;
        
        2)
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON Advanced Install initiated." >> $logfile
        exec sh /jffs/scripts/tailmon.sh -setup;;
        
        [Ee]) echo -e "${CClear}"; echo ""; exit 0;;
      esac

}

# -------------------------------------------------------------------------------------------------------------------------
# Expressinstall script

expressinstall() 
{

  echo ""
  echo -e "Ready to Express Install Tailscale?"
  if promptyn "[y/n]: "
    then
      if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
        echo ""
        echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
        echo ""
        opkg update
        echo ""
        echo -e "${CGreen}Installing Tailscale Package(s)...${CClear}"
        echo ""
        opkg install tailscale
        echo ""
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Entware package installed." >> $logfile
      else
        clear
        echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
        echo -e "Please install Entware using the AMTM utility before proceeding..."
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Entware was not found installed on router. Please investigate." >> $logfile
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exit 1
      fi
    else
      echo ""
      echo -e "${CClear}"
      exit 0
  fi
  
  echo ""
  echo -e "${CGreen}Applying settings for Userspace mode of operation...${CClear}"
    
    tsoperatingmode="Userspace"
    precmd=""
    args="--tun=userspace-networking --state=/opt/var/tailscaled.state"
    preargs="nohup"
    saveconfig
    
  echo ""
  echo -e "${CGreen}Applying settings to Tailscale service and connection...${CClear}"

  if [ -f "/opt/bin/tailscale" ]; then
    #make mods to the S06tailscaled service for Userspace mode
    if [ "$tsoperatingmode" == "Userspace" ]; then
    
      sed -i "s/^ARGS=.*/ARGS=\"--tun=userspace-networking\ --state=\/opt\/var\/tailscaled.state\"/" "/opt/etc/init.d/S06tailscaled"
      sed -i "s/^PREARGS=.*/PREARGS=\"nohup\"/" "/opt/etc/init.d/S06tailscaled"
      sed -i -e '/^PRECMD=/d' "/opt/etc/init.d/S06tailscaled"
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Userspace Mode settings have been applied." >> $logfile
      
      #remove firewall-start entry if found
      if [ -f /jffs/scripts/firewall-start ]; then

        if grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
          sed -i -e '/tailscale down/d' /jffs/scripts/firewall-start
        fi
      
      fi
    fi
  else
    echo ""
    echo -e "${CRed}ERROR: Tailscale binary was not found. Please check Entware and router/drive for errors.${CClear}"
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Tailscale binaries not found on router. Please investigate." >> $logfile
    exit 1
  fi
  
  echo ""
  echo -e "${CGreen}Starting Tailscale service...${CClear}"
  echo ""
  /opt/etc/init.d/S06tailscaled start
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Service started." >> $logfile
  
  echo ""
  echo ""
  echo -e "${CGreen}Starting Tailscale connection...${CClear}"
  echo ""
  echo -e "${CGreen}Please be prepared to copy and paste the link below into your browser, and connect this device"
  echo -e "to your tailnet (Tailscale Network)${CClear}"
  echo ""
  
  advroutescmd="--advertise-routes=$routes"
  echo -e "${CGreen}Executing: tailscale up $advroutescmd${CClear}"
  echo ""
  tailscale up $advroutescmd
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Connection started." >> $logfile

  echo ""
  echo ""
  echo -e "${CGreen}Express Install Completed Successfully!${CClear}"
  echo ""
  read -rsp $'Press any key to continue...\n' -n1 key
  
  exec sh /jffs/scripts/tailmon.sh -noswitch
  echo -e "${CClear}"
  exit 0
}

# -------------------------------------------------------------------------------------------------------------------------
# Install script

installts() 
{

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
        echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
        echo ""
        opkg update
        echo ""
        echo -e "${CGreen}Installing Tailscale Package(s)...${CClear}"
        echo ""
        opkg install tailscale
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Entware package installed." >> $logfile
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
      else
        clear
        echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
        echo -e "Please install Entware using the AMTM utility before proceeding..."
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Entware was not found on router. Please investigate." >> $logfile
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exit 1
      fi
  fi
  resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Uninstall script

uninstallts() 
{

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
      if [ -f /opt/bin/tailscale ]; then
        if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
          echo ""
          echo -e "\n${CGreen}Shutting down Tailscale...${CClear}"
          tailscale logout
          tailscale down
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Connection shut down and logged out." >> $logfile
          /opt/etc/init.d/S06tailscaled stop
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Service shut down." >> $logfile
          echo ""
          echo -e "\n${CGreen}Removing firewall-start entries...${CClear}"
          #remove firewall-start entry if found
          if [ -f /jffs/scripts/firewall-start ]; then
            if grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
              sed -i -e '/tailscale down/d' /jffs/scripts/firewall-start
              echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: firewall-start entries removed." >> $logfile
            fi
          fi
          echo ""
          echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
          echo ""
          opkg update
          echo ""
          echo -e "${CGreen}Uninstalling Entware Tailscale Package(s)...${CClear}"
          echo ""
          opkg remove tailscale
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Entware package removed." >> $logfile
          rm -f /opt/var/tailscaled.state >/dev/null 2>&1
          rm -r /opt/var/tailscale >/dev/null 2>&1
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale files and folders removed." >> $logfile
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key
        else
          clear
          echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
          echo -e "Please install Entware using the AMTM utility before proceeding..."
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Entware not found on router. Please investigate." >> $logfile
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key
          exit 1
        fi
      else
        echo ""
        echo -e "\n${CGreen}Tailscale was not found installed on this router.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
      fi
  fi
  resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# start service script

startts() 
{

      printf "\33[2K\r"
      printf "${CGreen}\r[Starting Tailscale Service]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:"
      echo ""
      /opt/etc/init.d/S06tailscaled start
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Service started." >> $logfile
      echo ""
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# stop service script

stopts() 
{

      printf "\33[2K\r"
      printf "${CGreen}\r[Stopping Tailscale Service]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:"
      echo ""
      /opt/etc/init.d/S06tailscaled stop
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Service stopped." >> $logfile
      echo ""
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Tailscale connection up

tsup() 
{

      printf "\33[2K\r"
      printf "${CGreen}\r[Activating Tailscale Connection]"
      sleep 3
      printf "\33[2K\r"
      
      if [ $exitnode -eq 1 ]; then exitnodecmd="--advertise-exit-node "; else exitnodecmd=""; fi
      if [ $advroutes -eq 1 ]; then advroutescmd="--advertise-routes=$routes"; else advroutescmd=""; fi

      echo -e "${CGreen}Messages:${CClear}"
      echo ""
      echo "Executing: tailscale up $exitnodecmd$advroutescmd"
      echo ""
      tailscale up $exitnodecmd$advroutescmd
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Connection started." >> $logfile
      sleep 3
      resettimer=1
}

# -------------------------------------------------------------------------------------------------------------------------
# Tailscale connection down

tsdown() 
{

      printf "\33[2K\r"
      printf "${CGreen}\r[Bringing Tailscale Connection Down]"
      sleep 3
      printf "\33[2K\r"
      echo -e "${CGreen}Messages:${CClear}"
      echo ""
      echo "Executing: tailscale down"
      echo ""
      tailscale down
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Tailscale Connection stopped." >> $logfile
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
# edittsoptions lets you edit the args for tailscale

edittsoptions()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Edit ARGS and PREARGS Options (userspace mode)                                        ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate what options you want in the Tailscale ARGS and PREARGS fields for${CClear}"
  echo -e "${InvGreen} ${CClear} the Tailscale S06Tailscaled service? It is recommended to leave these options as${CClear}"
  echo -e "${InvGreen} ${CClear} default to ensure the greatest amount of stability. Once you have made changes,${CClear}"
  echo -e "${InvGreen} ${CClear} please make sure to (S)ync Options, which will write your changes to the Tailscale${CClear}"
  echo -e "${InvGreen} ${CClear} Service file (/opt/etc/init.d/S06tailscaled)${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Defaults:${CClear}"
  echo -e "${InvGreen} ${CClear} ARGS=\"--tun=userspace-networking --state=/opt/var/tailscaled.state\"${CClear}"
  echo -e "${InvGreen} ${CClear} PREARGS=\"nohup\"${CClear})"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current values in /opt/etc/init.d/S06tailscaled:${CClear}"
  s06args=$(cat /opt/etc/init.d/S06tailscaled | grep ^ARGS= | cut -d '=' -f 2-) 2>/dev/null
  s06preargs=$(cat /opt/etc/init.d/S06tailscaled | grep ^PREARGS= | cut -d '=' -f 2-) 2>/dev/null
  echo -e "${InvGreen} ${CClear} ${CGreen}ARGS=$s06args${CClear}"
  echo -e "${InvGreen} ${CClear} ${CGreen}PREARGS=$s06preargs${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Saved TAILMON values:${CClear}"
  echo -e "${InvGreen} ${CClear} ${CGreen}(1) ARGS=\"$args\"${CClear}"
  echo -e "${InvGreen} ${CClear} ${CGreen}(2) PREARGS=\"$preargs\"${CClear}"
  echo -e "${InvGreen} ${CClear}"
  
  echo ""
  read -p "Please enter value (1-2)? (s=Sync Options) (e=Exit): " EnterTimerLoop
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
# operating mode lets the user choose between userspace and kernel modes of operation

operatingmode()
{

restartts=0
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Operating Mode Configuration                                                          ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Tailscale has 2 modes of operation: 'Userspace' and 'Kernel' mode. By default, the${CClear}"
  echo -e "${InvGreen} ${CClear} installer will configure Tailscale to operate in 'Userspace' mode, but in the end,${CClear}"
  echo -e "${InvGreen} ${CClear} should not make much difference performance-wise based on the hardware available in${CClear}"
  echo -e "${InvGreen} ${CClear} our routers. More info below:${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} In general, kernel mode (and thus only Linux, for now) should be used for heavily${CClear}"
  echo -e "${InvGreen} ${CClear} used subnet routers, where 'heavy' is some combination of number of users, number${CClear}"
  echo -e "${InvGreen} ${CClear} of flows, bandwidth. The userspace mode should be more than sufficient for smaller${CClear}"
  echo -e "${InvGreen} ${CClear} numbers of users or low bandwidth. Even though Tailscale's userspace subnet routing${CClear}"
  echo -e "${InvGreen} ${CClear} is not as optimized as the Linux kernel, it makes up for it slightly in being able${CClear}"
  echo -e "${InvGreen} ${CClear} to avoid some context switches to the kernel.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = Userspace Mode)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$tsoperatingmode${CClear}"
  echo ""
  read -p "Please enter value (1=Userspace, 2=Kernel)? (e=Exit): " EnterOperatingMode
  case $EnterOperatingMode in
    1)
      if [ "$tsoperatingmode" != "Userspace" ]; then restartts=1; fi
      tsoperatingmode="Userspace"
      precmd=""
      args="--tun=userspace-networking --state=/opt/var/tailscaled.state"
      preargs="nohup"
      saveconfig
      timer=$timerloop
    ;;

    2)
      if [ "$tsoperatingmode" != "Kernel" ]; then restartts=1; fi
      tsoperatingmode="Kernel"
      precmd="modprobe tun"
      args="--state=/opt/var/tailscaled.state"
      preargs="nohup"
      saveconfig
      timer=$timerloop
    ;;

    *)
      
      if [ -f "/opt/bin/tailscale" ]; then
        
        if [ $restartts -eq 1 ]; then
          echo ""
          echo -e "Changing operating modes will require a restart of Tailscale. Restart now?"
          if promptyn "[y/n]: "
            then
            echo ""
            echo -e "\n${CGreen}Restarting Tailscale Service and Connection...${CClear}"
            echo ""
            tsdown
            stopts

            #make mods to the S06tailscaled service for Userspace mode
            if [ "$tsoperatingmode" == "Userspace" ]; then
              applyuserspacemode
            
            #make mods to the S06tailscaled service for Kernel mode
            elif [ "$tsoperatingmode" == "Kernel" ]; then
              applykernelmode
            fi
            
            startts
            tsup

          fi
          
          echo ""
          echo -e "${CClear}[Exiting]"
          timer=$timerloop
          break

        else
        
          echo ""
          echo -e "${CClear}[Exiting]"
          timer=$timerloop
          break
        
        fi
      fi
    ;;
    
  esac

done

}

# -------------------------------------------------------------------------------------------------------------------------
# applyuserspacemode applies the standard settings for the Userspace operating mode

applyuserspacemode()
{
  sed -i "s/^ARGS=.*/ARGS=\"--tun=userspace-networking\ --state=\/opt\/var\/tailscaled.state\"/" "/opt/etc/init.d/S06tailscaled"
  sed -i "s/^PREARGS=.*/PREARGS=\"nohup\"/" "/opt/etc/init.d/S06tailscaled"
  sed -i -e '/^PRECMD=/d' "/opt/etc/init.d/S06tailscaled"
  
  #remove firewall-start entry if found
  if [ -f /jffs/scripts/firewall-start ]; then

    if grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
      sed -i -e '/tailscale down/d' /jffs/scripts/firewall-start
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: firewall-start entries removed." >> $logfile
    fi
  
  fi
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Userspace Mode settings have been applied." >> $logfile
}

# -------------------------------------------------------------------------------------------------------------------------
# applykernelmode applies the standard settings for the Kernel operating mode

applykernelmode()
{
  if ! grep -q -F "PRECMD=" /opt/etc/init.d/S06tailscaled; then
    sed '5 i PRECMD=\"modprobe tun\"' /opt/etc/init.d/S06tailscaled > /opt/etc/init.d/S06tailscaled2
    rm -f /opt/etc/init.d/S06tailscaled
    mv /opt/etc/init.d/S06tailscaled2 /opt/etc/init.d/S06tailscaled
    chmod 755 /opt/etc/init.d/S06tailscaled
  fi
  sed -i "s/^ARGS=.*/ARGS=\"--state=\/opt\/var\/tailscaled.state\"/" "/opt/etc/init.d/S06tailscaled"
  sed -i "s/^PREARGS=.*/PREARGS=\"nohup\"/" "/opt/etc/init.d/S06tailscaled"

  #modify/create firewall-start
  if [ -f /jffs/scripts/firewall-start ]; then

    if ! grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
      echo "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi # Added by TAILMON" >> /jffs/scripts/firewall-start
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: firewall-start entries created." >> $logfile
    fi

  else
    echo "#!/bin/sh" > /jffs/scripts/firewall-start
    echo "" >> /jffs/scripts/firewall-start
    echo "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi # Added by TAILMON" >> /jffs/scripts/firewall-start
    chmod 0755 /jffs/scripts/firewall-start
  fi
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Kernel Mode settings have been applied." >> $logfile
}

# -------------------------------------------------------------------------------------------------------------------------
# exitnodets provide a menu interface to allow for selection of router becoming an exitnode

exitnodets()
{
  
  clear
  if [ $exitnode -eq 0 ]; then exitnodedisp="No"; elif [ $exitnode -eq 1 ]; then exitnodedisp="Yes"; fi
    
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Configure Router as Exit Node                                                         ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} A Tailscale Exit Node is a feature that lets you route all non-Tailscale internet"
  echo -e "${InvGreen} ${CClear} traffic through a specific device on your Tailscale network (known as a tailnet)."
  echo -e "${InvGreen} ${CClear} The device routing your traffic (this router) is called an 'exit node'. Please"
  echo -e "${InvGreen} ${CClear} indicate below if you want to enable this feature"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = No)"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$exitnodedisp${CClear}"
  echo ""
  echo -e "Configure Router as Exit Node?"
  if promptyn "[y/n]: "
    then
      exitnode=1
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Device has been configured as Exit Node." >> $logfile
    else
      exitnode=0
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Exit Node configuration has been disabled." >> $logfile
  fi
  saveconfig
  timer=$timerloop
}

# -------------------------------------------------------------------------------------------------------------------------
# advroutests provide a menu interface to allow for entry of advertised routes

advroutests()
{
  
  clear
  if [ $advroutes -eq 0 ]; then advroutesdisp="No"; elif [ $advroutes -eq 1 ]; then advroutesdisp="Yes"; fi
    
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Advertise Routes on this Router                                                       ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Tailscale can act as a 'subnet router' that allow you to access multiple devices"
  echo -e "${InvGreen} ${CClear} located on your particular subnet through Tailscale. Subnet routers act as a"
  echo -e "${InvGreen} ${CClear} gateway, relaying traffic from your Tailscale network onto your physical subnet."
  echo -e "${InvGreen} ${CClear} If you need access to other devices, such as NAS, routers, computers, printers,"
  echo -e "${InvGreen} ${CClear} etc. without the need to install Tailscale software on them, it would be"
  echo -e "${InvGreen} ${CClear} recommended to enable this feature.  Please indicate your choice below."
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = Yes)"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$advroutesdisp${CClear}"
  echo -e "${InvGreen} ${CClear} ROUTE(S): ${CGreen}$routes${CClear}"
  echo ""
  echo -e "Advertise Routes?"
  if promptyn "[y/n]: "
    then
      echo ""
      echo ""
      echo -e "${InvGreen} ${InvDkGray}${CWhite} Advertise Routes on this Router                                                       ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} Please indicate what subnet you want to advertise to your Tailscale network."
      echo -e "${InvGreen} ${CClear} Typically, you would enter the current subnet of what your router is currently"
      echo -e "${InvGreen} ${CClear} configured for, ex: 192.168.50.0/24. Should you want to advertise multiple"
      echo -e "${InvGreen} ${CClear} subnets that are accessible by your router, comma-delimit them in this way:"
      echo -e "${InvGreen} ${CClear} 192.168.50.0/24,192.168.87.0/24,10.0.100.0/16"
      echo -e "${InvGreen} ${CClear}"
      echo -en "${InvGreen} ${CClear} (Default = "; echo -e "$(nvram get lan_ipaddr | cut -d"." -f1-3).0/24)"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo  ""
      read -p "Please enter valid IP4 subnet range? (e=Exit): " routeinput
      if [ "$routeinput" == "e" ]; then
        echo -e "\n[Exiting]"; sleep 2
      else 
        advroutes=1
        routes=$routeinput
        saveconfig
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Advertised routes enabled." >> $logfile
      fi
    else
      advroutes=0
      routes=""
      saveconfig
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Advertised routes disabled." >> $logfile
  fi
  timer=$timerloop
  
}

# -------------------------------------------------------------------------------------------------------------------------
# installdependencies checks for existence of entware, and if so proceed and install the packages, then run tailmon -config

installdependencies()
{

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
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Entware dependencies installed." >> $logfile
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
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Entware was not found installed on router. Please investigate." >> $logfile
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key
          exit 1
        fi
    else
      echo ""
      echo -e "\n${CClear}[Exiting]"
      echo ""
      sleep 2
      exit 0
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# reinstalldependencies force re-installs the entware packages

reinstalldependencies() 
{

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
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Entware dependencies re-installed." >> $logfile
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
      else
        clear
        echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
        echo -e "Please install Entware using the AMTM utility before proceeding..."
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Entware was not found installed on router. Please investigate." >> $logfile
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exit 1
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# vsetup provide a menu interface to allow for initial component installs, uninstall, etc.

vsetup()
{

if [ ! -f "/opt/bin/timeout" ] || [ ! -f "/opt/sbin/screen" ]; then
  installdependencies
fi

while true; do

  clear # Initial Setup
  if [ -f $config ]; then
    source $config
  else
    saveconfig
  fi 
  
  if [ -f "/opt/bin/tailscale" ]; then tsinstalleddisp="Installed"; else tsinstalleddisp="Not Installed"; fi
  if [ $exitnode -eq 0 ]; then exitnodedisp="No"; elif [ $exitnode -eq 1 ]; then exitnodedisp="Yes"; fi
  if [ $advroutes -eq 0 ]; then advroutesdisp="No"; elif [ $advroutes -eq 1 ]; then advroutesdisp="Yes ($routes)"; fi

  echo -e "${InvGreen} ${InvDkGray}${CWhite} TAILMON Main Setup and Configuration Menu                                             ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to perform high level${CClear}"
  echo -e "${InvGreen} ${CClear} actions in the management of the TAILMON script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Install Tailscale Entware Package(s)         : ${CGreen}$tsinstalleddisp${CClear}"

  printf "\33[2K\r"
  printf "${CGreen}\r[Checking Services...Stand By]"

  /opt/etc/init.d/S06tailscaled check >/dev/null 2>&1
  tsservice=$?
  if [ $tsservice -ne 0 ]; then tsservicedisp="Stopped"; else tsservicedisp="Started"; fi
  
  tailscale status >/dev/null 2>&1
  tsconn=$?
  if [ $tsconn -ne 0 ]; then tsconndisp="Disconnected"; else tsconndisp="Connected"; fi

  printf "\33[2K\r"

  if [ "$tsinstalleddisp" == "Installed" ]; then
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} |-${CClear}-- ${InvGreen}${CWhite}(S)${CClear}tart / S${InvGreen}${CWhite}(T)${CClear}op Tailscale Service${CClear}           |--- ${CGreen}$tsservicedisp${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} |-${CClear}-- ${InvGreen}${CWhite}(U)${CClear}p / ${InvGreen}${CWhite}(D)${CClear}own Tailscale Connection${CClear}           |--- ${CGreen}$tsconndisp${CClear}"
  fi

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Uninstall Tailscale Entware Package(s)${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Set Tailscale Operating Mode                 : ${CGreen}$tsoperatingmode${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Configure this Router as Exit Node           : ${CGreen}$exitnodedisp${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Advertise Routes on this router              : ${CGreen}$advroutesdisp${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : Custom configuration options for TAILMON${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(7)${CClear} : Force reinstall Entware dependencies${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(8)${CClear} : Check for latest updates${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(9)${CClear} : Uninstall TAILMON${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(L)${CClear} : Launch TAILMON in Monitoring Mode${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(M)${CClear} : Launch TAILMON in Monitoring Mode using SCREEN${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  if [ "$tsinstalleddisp" == "Installed" ]; then
    read -p "Please select? (1-9, S/T/U/D/L/M, e=Exit): " SelectSlot
  else
    read -p "Please select? (1-9, L/M, e=Exit): " SelectSlot
  fi
    case $SelectSlot in

      [Ss]) echo ""; startts;;
      
      [Tt]) echo ""; stopts;;
      
      [Uu]) echo ""; tsup;;
      
      [Dd]) echo ""; tsdown;;
      
      [Ll]) exec sh /jffs/scripts/tailmon.sh -noswitch;;
      
      [Mm]) exec sh /jffs/scripts/tailmon.sh -screen -now;;
    
      1) installts;;
      
      2) uninstallts;;
      
      3) if [ -f "/opt/bin/tailscale" ]; then operatingmode; fi;;
      
      4) if [ -f "/opt/bin/tailscale" ]; then exitnodetsl; fi;;
      
      5) if [ -f "/opt/bin/tailscale" ]; then advroutests; fi;;

      6) installdependencies;;

      7) reinstalldependencies;;
      
      8) vupdate;;
      
      9) vuninstall;;
      
      [Ee]) echo ""; timer=$timerloop; break;;
      
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
  initialsetup
fi 

while true; do

  if [ $keepalive -eq 0 ]; then
    keepalivedisp="No"
  else
    keepalivedisp="Yes"
  fi
  
  if [ $persistentsettings -eq 0 ]; then
    persistentsettingsdisp="No"
  else
    persistentsettingsdisp="Yes"
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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Keep settings on Tailscale Entware updates   : ${CGreen}$persistentsettingsdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-5, e=Exit): " SelectSlot
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
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON keepalive enabled." >> $logfile
          else
            keepalive=0
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON keepalive disabled." >> $logfile
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
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: Event log size configured for $logsize rows." >> $logfile
          else
            logsize=2000
            saveconfig
          fi
      ;;

      4)
        amtmevents
        source $config
      ;;
      
      5)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Keep Settings Persistent on Tailscale Entware Updates                                 ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate if you want TAILMON to check the Tailscale Service settings on${CClear}"
        echo -e "${InvGreen} ${CClear} a regular basis to determine if settings are out-of-sync due to a possible${CClear}"
        echo -e "${InvGreen} ${CClear} Tailscale Entware upgrade? A common side-effect after updating the Tailscale${CClear}"
        echo -e "${InvGreen} ${CClear} Entware package is that it will remove your previously configured settings,${CClear}"
        echo -e "${InvGreen} ${CClear} which could cause your router to no longer participate on your tailnet.${CClear}"        
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = No)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$persistentsettingsdisp${CClear}"
        echo ""
        echo -e "Keep Settings Persistent?"
        if promptyn "[y/n]: "
          then
            persistentsettings=1
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON Keep Settings Persistent enabled." >> $logfile
          else
            persistentsettings=0
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON Keep Settings Persistent disabled." >> $logfile
        fi
        saveconfig
      ;;

      
      [Ee]) echo -e "${CClear}\n[Exiting]"; sleep 2; resettimer=1; break ;;

    esac
done
}

# -------------------------------------------------------------------------------------------------------------------------
# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...

vupdate()
{

updatecheck # Check for the latest version from source repository
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Update Utility                                                                        ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This utility allows you to check, download and install updates"     
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Current Version: ${CGreen}$version${CClear}"
  echo -e "Updated Version: ${CGreen}$DLversion${CClear}"
  echo ""
  if [ "$version" == "$DLversion" ]
    then
      echo -e "You are on the latest version! Would you like to download anyways? This will overwrite${CClear}"
      echo -e "your local copy with the current build.${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo -e "\nDownloading TAILMON ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 5 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/TAILMON/main/tailmon.sh" -o "/jffs/scripts/tailmon.sh" && chmod 755 "/jffs/scripts/tailmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON update successfully downloaded and installed." >> $logfile
        echo ""
        read -rsp $'Press any key to restart TAILMON...\n' -n1 key
        exec /jffs/scripts/tailmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "Score! There is a new version out there! Would you like to update?${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo -e "\nDownloading TAILMON ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/TAILMON/main/tailmon.sh" -o "/jffs/scripts/tailmon.sh" && chmod 755 "/jffs/scripts/tailmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON update successfully downloaded and installed." >> $logfile
        echo ""
        read -rsp $'Press any key to restart TAILMON...\n' -n1 key
        exec /jffs/scripts/tailmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
done

}

# -------------------------------------------------------------------------------------------------------------------------
# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed

updatecheck()
{

  # Download the latest version file from the source repository
  curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/TAILMON/main/version.txt" -o "/jffs/addons/tailmon.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        DLversionPF=$(printf "%-8s" $DLversion)
        versionPF=$(printf "%-8s" $version)
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$versionPF -> v$DLversionPF                                                                     ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: New TAILMON v$DLversion available for download/install." >> $logfile
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# vuninstall is a function that uninstalls and removes all traces of tailmon/tailscale from your router...

vuninstall()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Uninstall Utility                                                                     ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} You are about to uninstall TAILMON and optionally, Tailscale from your router! This"
  echo -e "${InvGreen} ${CClear} action is irreversible."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Do you wish to proceed?${CClear}"
  if promptyn "[y/n]: "; then
    echo ""
    echo -e "\nAre you sure? Please type 'y' to validate you wish to proceed.${CClear}"
      if promptyn "[y/n]: "; then
        #Remove and uninstall files/directories
        rm -f -r /jffs/addons/tailmon.d >/dev/null 2>&1
        rm -f /jffs/scripts/tailmon.sh >/dev/null 2>&1
        echo ""
        echo -e "\n${CGreen}TAILMON has been uninstalled...${CClear}"
        echo ""
        if [ -f "/opt/bin/tailscale" ]; then
          echo -e "Would you also like to uninstall Tailscale from your router?"
          if promptyn "[y/n]: "; then
            if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
              echo ""
              echo -e "\n${CGreen}Shutting down Tailscale...${CClear}"
              tailscale logout
              tailscale down
              /opt/etc/init.d/S06tailscaled stop
              echo ""
              echo -e "\n${CGreen}Removing firewall-start entries...${CClear}"
              #remove firewall-start entry if found
              if [ -f /jffs/scripts/firewall-start ]; then
                if grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
                  sed -i -e '/tailscale down/d' /jffs/scripts/firewall-start
                fi
              fi
              echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
              echo ""
              opkg update
              echo ""
              echo -e "${CGreen}Uninstalling Entware Tailscale Package(s)...${CClear}"
              echo ""
              opkg remove tailscale
              rm -f /opt/var/tailscaled.state >/dev/null 2>&1
              rm -r /opt/var/tailscale >/dev/null 2>&1
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
              echo ""
              echo -e "${CClear}"
              exit 0
              break
            else
              clear
              echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
              echo -e "Please install Entware using the AMTM utility before proceeding..."
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
              exit 1
            fi
            exit 0
          else
            echo ""
            echo -e "\nExiting Uninstall Utility...${CClear}"
            sleep 1
            echo ""
            echo -e "${CClear}"
            exit 0
          fi
        fi
        exit 0
      else
        echo ""
        echo -e "\nExiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  fi      
done
}

# -------------------------------------------------------------------------------------------------------------------------
# vlogs is a function that calls the nano text editor to view the TAILMON log file

vlogs()
{

export TERM=linux
nano +999999 --linenumbers $logfile
timer=$timerloop
trimlogs

}

# -------------------------------------------------------------------------------------------------------------------------
# trimlogs will cut down log size (in rows) based on custom value

trimlogs()
{

  if [ $logsize -gt 0 ]; then

      currlogsize=$(wc -l $logfile | awk '{ print $1 }' ) # Determine the number of rows in the log

      if [ $currlogsize -gt $logsize ] # If it's bigger than the max allowed, tail/trim it!
        then
          echo "$(tail -$logsize $logfile)" > $logfile
      fi

  fi
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
     echo 'tsoperatingmode="'"$tsoperatingmode"'"'
     echo 'persistentsettings='$persistentsettings
     echo 'exitnode='$exitnode
     echo 'advroutes='$advroutes
     echo 'precmd="'"$precmd"'"'
     echo 'args="'"$args"'"'
     echo 'preargs="'"$preargs"'"'
     echo 'routes="'"$routes"'"'
   } > $config
   echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - INFO: TAILMON config has been updated." >> $logfile
}

# -------------------------------------------------------------------------------------------------------------------------

# Check for updates
updatecheck

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
  echo "tailmon -h | -help"
  echo "tailmon -setup"
  echo "tailmon -bw"
  echo "tailmon -screen"
  echo "tailmon -screen -now"
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
      initialsetup
    fi
fi

# -------------------------------------------------------------------------------------------------------------------------
# Begin TAILMON Main Loop
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

# Create the necessary folder/file structure for tailmon under /jffs/addons
if [ ! -d "/jffs/addons/tailmon.d" ]; then
  mkdir -p "/jffs/addons/tailmon.d"
fi

# Check for and add an alias for TAILMON
if ! grep -F "sh /jffs/scripts/tailmon.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
  echo "alias tailmon=\"sh /jffs/scripts/tailmon.sh\" # added by tailmon" >> /jffs/configs/profile.add
fi

if [ ! -f "/opt/bin/timeout" ] || [ ! -f "/opt/sbin/screen" ]; then
  installdependencies
fi

if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
  then
    timeoutcmd="timeout "
    timeoutsec="10"
    timeoutlng="60"
  else
    timeoutcmd=""
    timeoutsec=""
    timeoutlng=""
fi
  
while true; do

  # Grab the TAILMON config file and read it in
  if [ -f $config ]; then
    source $config
  else
    initialsetup
  fi 
  
  if [ -f "/opt/bin/tailscale" ]; then
    tsinstalled=1
    clear
    
    if [ $keepalive -eq 1 ]; then
      keepalivedisp="Yes"
    else
      keepalivedisp="No"
    fi
    
    if [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "0" ]; then
      amtmdisp="${CDkGray}Disabled        "
    elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "0" ]; then
      amtmdisp="${CGreen}Success         "
    elif [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "1" ]; then
      amtmdisp="${CGreen}Failure         "
    elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "1" ]; then
      amtmdisp="${CGreen}Success, Failure"
    else
      amtmdisp="${CDkGray}Disabled        "
    fi
  
    tzone=$(date +%Z)
    tzonechars=$(echo ${#tzone})

    if [ $tzonechars = 1 ]; then tzspaces="        ";
    elif [ $tzonechars = 2 ]; then tzspaces="       ";
    elif [ $tzonechars = 3 ]; then tzspaces="      ";
    elif [ $tzonechars = 4 ]; then tzspaces="     ";
    elif [ $tzonechars = 5 ]; then tzspaces="    "; fi

    #Display tailmon Update Notifications
    if [ "$UpdateNotify" != "0" ]; then echo -e "$UpdateNotify"; fi

    #Display tailmon client header
    echo -en "${InvGreen} ${InvDkGray} TAILMON - v"
    printf "%-8s" $version
    echo -e "                           ${CWhite}Operations Menu ${InvDkGray}            $tzspaces$(date) ${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(S)${CClear}tart / S${CGreen}(T)${CClear}op Tailscale Service                   ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu${CClear}"
    echo -e "${InvGreen} ${CClear} Tailscale Connection ${CGreen}(U)${CClear}p / ${CGreen}(D)${CClear}own                   ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): ${CGreen}$logsize${CClear}"
    echo -e "${InvGreen} ${CClear} Custom Service/Commandline Options (TBD)             ${InvGreen} ${CClear} ${CGreen}(K)${CClear}eep Tailscale Service Alive: ${CGreen}$keepalivedisp${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(A)${CClear}MTM Email Notifications: $amtmdisp         ${InvGreen} ${CClear} Ti${CGreen}(M)${CClear}er Check Loop Interval: ${CGreen}${timerloop}sec${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
    echo -e "${InvDkGray}${CWhite}Tailscale Service:                                                                                             ${CClear}"
    /opt/etc/init.d/S06tailscaled check
    tsservice=$?
    
    echo ""
    echo -e "${InvDkGray}${CWhite}Tailscale Connection Status:                                                                                   ${CClear}"
    tailscale status
    echo ""
    
    if [ "$tsoperatingmode" == "Userspace" ]; then
      echo -e "${InvDkGray}${CWhite}Tailscale Service Options (Userspace Mode)                                                                     ${CClear}"
      echo -e "${CWhite}ARGS: ${CGreen}$args"
      echo -e "${CWhite}PREARGS: ${CGreen}$preargs"
    elif [ "$tsoperatingmode" == "Kernel" ]; then
      echo -e "${InvDkGray}${CWhite}Tailscale Service Options (Kernel Mode)                                                                        ${CClear}"
      echo -e "${CWhite}PRECMD: ${CGreen}$precmd"
      echo -e "${CWhite}ARGS: ${CGreen}$args"
      echo -e "${CWhite}PREARGS: ${CGreen}$preargs"
    fi
    
    echo ""
    echo -e "${InvDkGray}${CWhite}Tailscale Connection Commandline                                                                               ${CClear}"
    
    if [ $exitnode -eq 1 ]; then exitnodecmd="--advertise-exit-node "; else exitnodecmd=""; fi
    if [ $advroutes -eq 1 ]; then advroutescmd="--advertise-routes=$routes"; else advroutescmd=""; fi
        
    echo -e "${CWhite}${CGreen}$exitnodecmd$advroutescmd${CClear}"
    echo ""
    #read -rsp $'Press any key to continue...\n' -n1 key
  
  else
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Tailscale binaries not found. Please investigate." >> $logfile
    tsinstalled=0
    exec sh /jffs/scripts/tailmon.sh -setup
  fi

  #Determine if S06tailscaled service settings have changed
  if [ $tsinstalled -eq 1 ] && [ $persistentsettings -eq 1 ]; then
    
    s06args=$(cat /opt/etc/init.d/S06tailscaled | grep ^ARGS= | cut -d '=' -f 2-) 2>/dev/null
    tailmonargs="\"$args\""
    
    if [ "$s06args" != "$tailmonargs" ]; then
      printf "\33[2K\r"
      printf "${CGreen}\r[Tailscale Service settings out-of-sync]"
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Tailscale Service settings are out-of-sync." >> $logfile
      sleep 3
      
      tsdown
      stopts
      
      #make mods to the S06tailscaled service for Userspace mode
      if [ "$tsoperatingmode" == "Userspace" ]; then
        applyuserspacemode
      #make mods to the S06tailscaled service for Kernel mode
      elif [ "$tsoperatingmode" == "Kernel" ]; then
        applykernelmode
      fi
      
      printf "\33[2K\r"
      printf "${CGreen}\r[Tailscale Service settings synced]"
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Tailscale Service settings synced." >> $logfile
      sleep 3
      
      startts
      tsup
      
      sleep 3
      resettimer=1
    fi
    
  fi

  #Determine if Tailscale service is down
  if [ $tsinstalled -eq 1 ] && [ $keepalive -eq 1 ]; then
    if [ $tsservice -ne 0 ]; then
      printf "\33[2K\r"
      printf "${CGreen}\r[Tailscale Service appears dead]"
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) TAILMON[$$] - ERROR: Tailscale Service appears dead." >> $logfile
      sleep 3

      startts

      tsup

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
