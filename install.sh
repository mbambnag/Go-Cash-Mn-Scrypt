#!/bin/bash
TMP_FOLDER=$(mktemp -d)
COIN_NAME="GoCash [gocash]"
CONFIG_FILE="gocash.conf"
CONFIGFOLDER=".gocash"
DEFAULTUSER="gocash-mn1"
DEFAULTPORT=9911
BINARY_NAME="gocashd"
BINARY_FILE="/usr/local/bin/$BINARY_NAME"
CLI_NAME="gocash-cli"
CLI_FILE="/usr/local/bin/$CLI_NAME"
COIN_TGZ="https://github.com/mbambnag/GoCash-Core/releases/download/v.1.1.1.5/linux-cli1.5.tar.gz"
COIN_ZIP='linux-cli1.5.tar.gz'
GITHUB_REPO="https://github.com/mbambnag/GoCash-Core"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function checks() 
{
  if [[ $(lsb_release -d) != *16.04* ]]; then
    echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root.${NC}"
     exit 1
  fi

  if [ -n "$(pidof $BINARY_NAME)" ]; then
    read -e -p "$(echo -e The $COIN_NAME daemon is already running.$YELLOW Do you want to add another master node? [Y/N] $NC)" NEW_NODE
    clear
  else
    NEW_NODE="new"
  fi
}

function prepare_system() 
{
  clear
  echo -e "Checking if swap space is required."
  PHYMEM=$(free -g | awk '/^Mem:/{print $2}')
  
  if [ "$PHYMEM" -lt "2" ]; then
    SWAP=$(swapon -s get 1 | awk '{print $1}')
    if [ -z "$SWAP" ]; then
      echo -e "${GREEN}Server is running without a swap file and has less than 2G of RAM, creating a 2G swap file.${NC}"
      dd if=/dev/zero of=/swapfile bs=4096 count=4M
      chmod 600 /swapfile
      mkswap /swapfile
      swapon -a /swapfile
    else
      echo -e "${GREEN}Swap file already exists.${NC}"
    fi
  else
    echo -e "${GREEN}Server running with at least 2G of RAM, no swap file needed.${NC}"
  fi
  
  echo -e "${GREEN}Updating package manager.${NC}"
  apt update
  
  echo -e "${GREEN}Upgrading existing packages, it may take some time to finish.${NC}"
  DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade 
  
  echo -e "${GREEN}Installing all dependencies for the ${RED}$COIN_NAME${NC} Master node, it may take some time to finish.${NC}"
  apt-add-repository -y ppa:bitcoin/bitcoin
  apt-get update >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
  apt install -y software-properties-common >/dev/null 2>&1
  apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
  apt-get update >/dev/null 2>&1
  apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
  build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
  libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
  libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ libzmq5 unzip>/dev/null 2>&1

  clear
  
  if [ "$?" -gt "0" ]; then
      echo -e "${RED}Not all of the required packages were installed correctly.\n"
      echo -e "Try to install them manually by running the following commands:${NC}\n"
      echo -e "apt update"
      echo -e "apt -y install software-properties-common"
      echo -e "apt-add-repository -y ppa:bitcoin/bitcoin"
      echo -e "apt update"
      echo -e "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pkg-config libevent-dev libzmq5"

   exit 1
  fi

  clear
}

function deploy_binary() 
{
  if [ -f $BINARY_FILE ]; then
    echo -e "${GREEN}$COIN_NAME daemon binary file already exists, using binary from $BINARY_FILE.${NC}"
  else
    cd $TMP_FOLDER

    echo -e "${GREEN}Downloading $COIN_ZIP and deploying the $COIN_NAME service.${NC}"
    wget $COIN_TGZ -O $COIN_ZIP.zip >/dev/null 2>&1

    tar xvzf $COIN_ZIP.zip >/dev/null 2>&1
    cp $BINARY_NAME $CLI_NAME /usr/local/bin/
    chmod +x $BINARY_FILE >/dev/null 2>&1
    chmod +x $CLI_FILE >/dev/null 2>&1
    cd

    rm -rf $TMP_FOLDER
  fi
}

function enable_firewall() 
{
  echo -e "${GREEN}Installing fail2ban and setting up firewall to allow access on port $DAEMONPORT.${NC}"

  apt install ufw -y >/dev/null 2>&1

  ufw disable >/dev/null 2>&1
  ufw allow $DAEMONPORT/tcp comment "Masternode port" >/dev/null 2>&1
  ufw allow $[DAEMONPORT+1]/tcp comment "Masernode RPC port" >/dev/null 2>&1
  ufw allow $DEFAULTPORT/tcp comment "Allow Default Coin Port" >/dev/null 2>&1
  ufw allow 22/tcp comment "Allow SSH" >/dev/null 2>&1
  
  ufw logging on >/dev/null 2>&1
  ufw default deny incoming >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1


  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function add_daemon_service() 
{
  cat << EOF > /etc/systemd/system/$COINUSER.service
[Unit]
Description=$COIN_NAME daemon service
After=network.target
After=syslog.target
[Service]
Type=forking
User=$COINUSER
Group=$COINUSER
WorkingDirectory=$COINFOLDER
ExecStart=$BINARY_FILE -datadir=$COINFOLDER -conf=$COINFOLDER/$CONFIG_FILE -daemon 
ExecStop=$CLI_FILE stop
Restart=always
RestartSec=3
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3

  echo -e "${GREEN}Starting the gocash service from $BINARY_FILE on port $DAEMONPORT.${NC}"
  systemctl start $COINUSER.service >/dev/null 2>&1
  
  echo -e "${GREEN}Enabling the service to start on reboot.${NC}"
  systemctl enable $COINUSER.service >/dev/null 2>&1

  if [[ -z $(pidof $BINARY_NAME) ]]; then
    echo -e "${RED}The $COIN_NAME masternode service is not running${NC}. You should start by running the following commands as root:"
    echo "systemctl start $COINUSER.service"
    echo "systemctl status $COINUSER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function ask_port() 
{
  read -e -p "$(echo -e $YELLOW Enter a port to run the $COIN_NAME service on: $NC)" -i $DEFAULTPORT DAEMONPORT
}

function ask_user() 
{  
  read -e -p "$(echo -e $YELLOW Enter a new username to run the $COIN_NAME service as: $NC)" -i $DEFAULTUSER COINUSER

  if [ -z "$(getent passwd $COINUSER)" ]; then
    useradd -m $COINUSER
    USERPASS=$(pwgen -s 12 1)
    echo "$COINUSER:$USERPASS" | chpasswd

    COINHOME=$(sudo -H -u $COINUSER bash -c 'echo $HOME')
    COINFOLDER="$COINHOME/$CONFIGFOLDER"
        
    mkdir -p $COINFOLDER
    chown -R $COINUSER: $COINFOLDER >/dev/null 2>&1
  else
    clear
    echo -e "${RED}User already exists. Please enter another username.${NC}"
    ask_user
  fi
}

function check_port() 
{
  declare -a PORTS

  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $DAEMONPORT ]] || [[ ${PORTS[@]} =~ $[DAEMONPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function ask_ip() 
{
  declare -a NODE_IPS
  declare -a NODE_IPS_STR

  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    ipv4=$(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com)
    NODE_IPS+=($ipv4)
    NODE_IPS_STR+=("$(echo -e [IPv4] $ipv4)")

    ipv6=$(curl --interface $ips --connect-timeout 2 -s6 icanhazip.com)
    NODE_IPS+=($ipv6)
    NODE_IPS_STR+=("$(echo -e [IPv6] $ipv6)")
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP address found.${NC}"
      INDEX=0
      for ip in "${NODE_IPS_STR[@]}"
      do
        echo -e " ${YELLOW}[${INDEX}] $ip${NC}"
        let INDEX=${INDEX}+1
      done
      echo -e " ${YELLOW}Which IP address do you want to use? Type 0 to use the first IP, 1 for the second and so on ...${NC}"
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}

function create_config() 
{
#Script Created by Mbambnag
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $COINFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[DAEMONPORT+1]
listen=0
server=1
daemon=1
txindex=1
port=$DAEMONPORT
addnode=47.254.46.118:9911
addnode=149.28.169.115:9911
addnode=73.255.148.181:9911
addnode=83.79.38.57:9911
addnode=101.180.5.119:9911
addnode=118.38.99.125:9911
addnode=207.148.9.75:9911
addnode=76.169.4.118:9911
addnode=149.28.126.31:9911
addnode=122.169.8.234:9911
addnode=23.94.136.165:9911
addnode=36.74.153.225:9911
addnode=112.215.172.80:9911
addnode=45.76.61.220:9911
addnode=47.254.33.204:9911
addnode=165.73.50.200:9911
addnode=36.69.131.37:9911
addnode=144.202.61.134:9911
addnode=192.227.215.169:9911
addnode=98.214.20.153:9911
addnode=201.53.46.148:9911
addnode=173.48.82.37:9911
addnode=90.254.158.239:9911
addnode=178.120.10.82:9911
addnode=180.191.74.218:9911
addnode=36.70.206.23:9911
addnode=122.173.15.75:9911
addnode=151.106.19.121:9911
addnode=183.81.155.6:9911
addnode=173.90.87.168:9911
addnode=45.76.251.234:9911
addnode=46.33.239.29:9911
addnode=36.80.67.175:9911
addnode=180.243.188.73:9911
addnode=168.195.101.48:9911
addnode=221.37.194.27:9911
addnode=115.178.211.116:9911
addnode=99.95.101.88:9911
addnode=99.59.239.8:9911
addnode=112.215.153.161:9911
EOF
}

function create_key() 
{
  read -e -p "$(echo -e $YELLOW Paste your masternode private key. Leave it blank to generate a new private key.$NC)" COINPRIVKEY

  if [[ -z "$COINPRIVKEY" ]]; then
    sudo -u $COINUSER $BINARY_FILE -datadir=$COINFOLDER -conf=$COINFOLDER/$CONFIG_FILE -daemon >/dev/null 2>&1
    sleep 5

    if [ -z "$(pidof $BINARY_NAME)" ]; then
    echo -e "${RED}$COIN_NAME deamon couldn't start, could not generate a private key. Check /var/log/syslog for errors.${NC}"
    exit 1
    fi

    COINPRIVKEY=$(sudo -u $COINUSER $CLI_FILE -datadir=$COINFOLDER -conf=$COINFOLDER/$CONFIG_FILE masternode genkey) 
    sudo -u $COINUSER $CLI_FILE -datadir=$COINFOLDER -conf=$COINFOLDER/$CONFIG_FILE stop >/dev/null 2>&1
    sleep 5
  fi
}

function update_config() 
{  
  cat << EOF >> $COINFOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
masternode=1
externalip=$NODEIP
masternodeprivkey=$COINPRIVKEY
EOF
  chown $COINUSER: $COINFOLDER/$CONFIG_FILE >/dev/null
}

function add_log_truncate()
{
  LOG_FILE="$COINFOLDER/debug.log";

  mkdir ~/.gocash >/dev/null 2>&1
  cat << EOF >> $DATA_DIR/gocash.conf
$DATA_DIR/*.log {
    rotate 4
    weekly
    compress
    missingok
    notifempty
}
EOF

  if ! crontab -l | grep "/home/$USER_NAME/gocash.conf"; then
    (crontab -l ; echo "1 0 * * 1 /usr/sbin/gocash $DATA_DIR/gocash.conf --state $DATA_DIR/gocash-state") | crontab -
  fi
}

function show_output() 
{
 echo
 echo -e "================================================================================================================================"
 echo
 echo -e "Your Go CASH coin master node is up and running." 
 echo -e " - it is running as user ${GREEN}$COINUSER${NC} and it is listening on port ${GREEN}$DAEMONPORT${NC} at your VPS address ${GREEN}$NODEIP${NC}."
 echo -e " - the ${GREEN}$COINUSER${NC} password is ${GREEN}$USERPASS${NC}"
 echo -e " - the Go CASH configuration file is located at ${GREEN}$COINFOLDER/$CONFIG_FILE${NC}"
 echo -e " - the masternode privkey is ${GREEN}$COINPRIVKEY${NC}"
 echo
 echo -e "You can manage your Go CASH service from the cmdline with the following commands:"
 echo -e " - ${GREEN}systemctl start $COINUSER.service${NC} to start the service for the given user."
 echo -e " - ${GREEN}systemctl stop $COINUSER.service${NC} to stop the service for the given user."
 echo -e " - ${GREEN}systemctl status $COINUSER.service${NC} to see the service status for the given user."
 echo
 echo -e "The installed service is set to:"
 echo -e " - auto start when your VPS is rebooted."
 echo -e " - rotate your ${GREEN}$LOG_FILE${NC} file once per week and keep the last 4 weeks of logs."
 echo
 echo -e "You can find the masternode status when logged in as $COINUSER using the command below:"
 echo -e " - ${GREEN}${CLI_NAME} getinfo${NC} to retreive your nodes status and information"
 echo
 echo -e "  if you are not logged in as $COINUSER then you can run ${YELLOW}su - $COINUSER${NC} to switch to that user before"
 echo -e "  running the ${GREEN}${CLI_NAME} getinfo${NC} command."
 echo -e "  NOTE: the ${BINARY_NAME} daemon must be running first before trying this command. See notes above on service commands usage."
 echo
 echo -e "================================================================================================================================"
 echo
}

function setup_node() 
{
  ask_user
  check_port
  ask_ip
  create_config
  create_key
  update_config
  enable_firewall
  add_daemon_service
  add_log_truncate
  show_output
}

clear

echo
echo -e "============================================================================================================="
echo -e "${GREEN}"
echo -e pool.asic.network                       
echo -e "${NC}"
echo -e "This script will automate the installation of your $COIN_NAME coin masternode and server configuration by"
echo -e "performing the following steps:"
echo
echo -e " - Prepare your system with the required dependencies"
echo -e " - Obtain the latest gocash masternode files from the $COIN_NAME  GitHub repository"
echo -e " - Create a user and password to run the $COIN_NAME masternode service"
echo -e " - Install the $COIN_NAME  masternode service under the new user [not root]"
echo -e " - Add DDoS protection using fail2ban"
echo -e " - Update the system firewall to only allow; the masternode ports and outgoing connections"
echo -e " - Rotate and archive the masternode logs to save disk space"
echo
echo -e "The script will output ${YELLOW}questions${NC}, ${GREEN}information${NC} and ${RED}errors${NC}"
echo -e "When finished the script will show a summary of what has been done."
echo
echo -e "Script created by Mbambnag"
echo 
echo -e "============================================================================================================="
echo
read -e -p "$(echo -e $YELLOW Do you want to continue? [Y/N] $NC)" CHOICE

if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
  exit 1;
fi

checks

if [[ ("$NEW_NODE" == "y" || "$NEW_NODE" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_NODE" == "new" ]]; then
  prepare_system
  deploy_binary
  setup_node
else
  echo -e "${GREEN}$COIN_NAME daemon already running.${NC}"
  exit 0
fi
