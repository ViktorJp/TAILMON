#!/bin/sh

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="0.0.1"
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
tsoperatingmode="Userspace"
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
          [Cc]) vsetup;;
          [Dd]) tsdown;;
          [Ee]) logoNMexit; echo -e "${CClear}\n"; exit 0;;
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
        rm /opt/var/tailscaled.state
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
      tsoperatingmode="Userspace"
      precmd=""
      args="--tun=userspace-networking --state=/opt/var/tailscaled.state"
      preargs="nohup"
      saveconfig
      timer=$timerloop
    ;;

    2)
      tsoperatingmode="Kernel"
      precmd="modprobe tun"
      args="--state=/opt/var/tailscaled.state"
      preargs="nohup"
      saveconfig
      timer=$timerloop
    ;;

    *)
      
      if [ -f "/opt/bin/tailscale" ]; then
        #make mods to the S06tailscaled service for Userspace mode
        if [ "$tsoperatingmode" == "Userspace" ]; then
        
          sed -i "s/^ARGS=.*/ARGS=\"--tun=userspace-networking\ --state=\/opt\/var\/tailscaled.state\"/" "/opt/etc/init.d/S06tailscaled"
          sed -i "s/^PREARGS=.*/PREARGS=\"nohup\"/" "/opt/etc/init.d/S06tailscaled"
          sed -i -e '/^PRECMD=/d' "/opt/etc/init.d/S06tailscaled"
          
          #remove firewall-start entry if found
          if [ -f /jffs/scripts/firewall-start ]; then

            if grep -q -F "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi" /jffs/scripts/firewall-start; then
              sed -i -e '/tailscale down/d' /jffs/scripts/firewall-start
            fi
          
          fi
        
        #make mods to the S06tailscaled service for Kernel mode
        elif [ "$tsoperatingmode" == "Kernel" ]; then
        
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
            fi

          else
            echo "#!/bin/sh" > /jffs/scripts/firewall-start
            echo "" >> /jffs/scripts/firewall-start
            echo "if [ -x /opt/bin/tailscale ]; then tailscale down; tailscale up; fi # Added by TAILMON" >> /jffs/scripts/firewall-start
            chmod 0755 /jffs/scripts/firewall-start
          fi
        
        fi
      fi
      
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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-9, e=Exit): " SelectSlot
    case $SelectSlot in
      1) installts;;
      
      2) uninstallts;;
      
      3) operatingmode;;
      
      4)
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
          else
            exitnode=0
        fi
        saveconfig
        timer=$timerloop
      ;;
      
      5)
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
            echo -e "${InvGreen} ${CClear} (Default = 192.168.50.0/24)"
            echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
            echo  ""
            read -p "Please enter valid IP4 subnet range? (e=Exit): " routeinput
            if [ "$routeinput" == "e" ]; then
              echo -e "\n[Exiting]"; sleep 2
            else 
              advroutes=1
              routes=$routeinput
              saveconfig
            fi
          else
            advroutes=0
            routes=""
            saveconfig
        fi
        timer=$timerloop
      ;;

      6) # Check for existence of entware, and if so proceed and install the timeout package, then run tailmon -config
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

      7) # Force re-install the CoreUtils timeout/screen package
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
      8) vupdate;;
      9) vuninstall;;
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
        curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/TAILMON/main/vpnmon-r3.sh" -o "/jffs/scripts/tailmon.sh" && chmod 755 "/jffs/scripts/tailmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
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
        clear
        #Remove and uninstall files/directories
        rm -f -r /jffs/addons/tailmon.d
        rm -f /jffs/scripts/tailmon.sh
        echo ""
        echo -e "\nTAILMON has been uninstalled...${CClear}"
        echo ""
        echo -e "Would you also like to uninstall Tailscale from your router?"
        if promptyn "[y/n]: "; then
          if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
            echo ""
            echo -e "\nUpdating Entware Packages..."
            echo ""
            opkg update
            echo ""
            echo -e "Uninstalling Tailscale Package(s)..."
            echo ""
            opkg remove tailscale
            rm -f /opt/var/tailscaled.state
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
          exit 0
        else
          echo ""
          echo -e "\nExiting Uninstall Utility...${CClear}"
          sleep 1
          return
        fi
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
     echo 'exitnode='$exitnode
     echo 'advroutes='$advroutes
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

    #Display VPNMON-R3 client header
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
    if [ $advroutes -eq 1 ]; then advroutescmd="--accept-routes --advertise-routes=$routes"; else advroutescmd=""; fi
        
    echo -e "${CWhite}${CGreen}$exitnodecmd$advroutescmd${CClear}"
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
      echo "Executing: tailscale up $exitnodecmd$advroutescmd"
      echo ""
      tailscale up $exitnodecmd $advroutescmd
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