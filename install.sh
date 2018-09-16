#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='gocash.conf'
CONFIGFOLDER='/root/.gocash'
COIN_DAEMON='gocashd'
COIN_CLI='gocash-cli'
COIN_PATH='/usr/local/bin/'
COIN_TGZ='https://github.com/mbambnag/GoCash-Core/releases/download/1.1.1.6/linux-cli-1-6.tar.gz'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
COIN_NAME='gocash'
COIN_PORT=9911

NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'

GREEN='\033[0;32m'

NC='\033[0m'





function download_node() {

  echo -e "Prepare to download ${PURPLE}$COIN_NAME${NC}."

  cd $TMP_FOLDER >/dev/null 2>&1

  wget -q $COIN_TGZ

  compile_error

  tar xvzf $COIN_ZIP

  chmod +x $COIN_DAEMON $COIN_CLI

  cp $COIN_DAEMON $COIN_CLI $COIN_PATH

  cd ~ >/dev/null 2>&1

  rm -rf $TMP_FOLDER >/dev/null 2>&1

  clear

}





function configure_systemd() {

  cat << EOF > /etc/systemd/system/$COIN_NAME.service

[Unit]

Description=$COIN_NAME service

After=network.target

[Service]

User=root

Group=root

Type=forking

#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER

ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always

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

  systemctl start $COIN_NAME.service

  systemctl enable $COIN_NAME.service >/dev/null 2>&1



  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then

    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"

    echo -e "${GREEN}systemctl start $COIN_NAME.service"

    echo -e "systemctl status $COIN_NAME.service"

    echo -e "less /var/log/syslog${NC}"

    exit 1

  fi

}





function create_config() {

  mkdir $CONFIGFOLDER >/dev/null 2>&1

  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)

  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)

  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE

rpcuser=$RPCUSER

rpcpassword=$RPCPASSWORD

#rpcport=$RPC_PORT

rpcallowip=127.0.0.1

listen=1

server=1

daemon=1

port=$COIN_PORT

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



function create_key() {

  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"

  read -e COINKEY

  if [[ -z "$COINKEY" ]]; then

  $COIN_PATH$COIN_DAEMON -daemon

  sleep 30

  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then

   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"

   exit 1

  fi

  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)

  if [ "$?" -gt "0" ];

    then

    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the Private Key${NC}"

    sleep 30

    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)

  fi

  $COIN_PATH$COIN_CLI stop

fi

clear

}



function update_config() {

  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE

  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE

logintimestamps=1

maxconnections=256

#bind=$NODEIP

masternode=1

externalip=$NODEIP:$COIN_PORT

masternodeprivkey=$COINKEY

EOF

}





function enable_firewall() {

  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"

  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null

  ufw allow ssh comment "SSH" >/dev/null 2>&1

  ufw limit ssh/tcp >/dev/null 2>&1

  ufw default allow outgoing >/dev/null 2>&1

  echo "y" | ufw enable >/dev/null 2>&1

}





function get_ip() {

  declare -a NODE_IPS

  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')

  do

    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))

  done



  if [ ${#NODE_IPS[@]} -gt 1 ]

    then

      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"

      INDEX=0

      for ip in "${NODE_IPS[@]}"

      do

        echo ${INDEX} $ip

        let INDEX=${INDEX}+1

      done

      read -e choose_ip

      NODEIP=${NODE_IPS[$choose_ip]}

  else

    NODEIP=${NODE_IPS[0]}

  fi

}





function compile_error() {

if [ "$?" -gt "0" ];

 then

  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"

  exit 1

fi

}





function checks() {

if [[ $(lsb_release -d) != *16.04* ]]; then

  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"

  exit 1

fi



if [[ $EUID -ne 0 ]]; then

   echo -e "${RED}$0 must be run as root.${NC}"

   exit 1

fi



if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then

  echo -e "${RED}$COIN_NAME is already installed.${NC}"

  exit 1

fi

}



function prepare_system() {

echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."

apt-get update >/dev/null 2>&1

DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1

DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1

apt install -y software-properties-common >/dev/null 2>&1

echo -e "${GREEN}Adding bitcoin PPA repository"

apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1

echo -e "Installing required packages, it may take some time to finish.${NC}"

apt-get update >/dev/null 2>&1

apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \

build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \

libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \

libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip libzmq5 >/dev/null 2>&1

if [ "$?" -gt "0" ];

  then

    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"

    echo "apt-get update"

    echo "apt -y install software-properties-common"

    echo "apt-add-repository -y ppa:bitcoin/bitcoin"

    echo "apt-get update"

    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \

libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \

bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"

 exit 1

fi

clear

}



function important_information() {

 echo -e "================================================================================================================================"

 echo -e "$COIN_NAME Masternode is up and running listening on port ${RED}$COIN_PORT${NC}."

 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"

 echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"

 echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"

 echo -e "VPS_IP:PORT ${RED}$NODEIP:$COIN_PORT${NC}"

 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"

 echo -e "Please check ${RED}$COIN_NAME${NC} daemon is running with the following command: ${RED}systemctl status $COIN_NAME.service${NC}"

 echo -e "Use ${RED}$COIN_CLI masternode status${NC} to check your MN."

 if [[ -n $SENTINEL_REPO  ]]; then

  echo -e "${RED}Sentinel${NC} is installed in ${RED}$CONFIGFOLDER/sentinel${NC}"

  echo -e "Sentinel logs is: ${RED}$CONFIGFOLDER/sentinel.log${NC}"

 fi

 echo -e "================================================================================================================================"

}



function setup_node() {

  get_ip

  create_config

  create_key

  update_config

  enable_firewall

  important_information

  configure_systemd

}





##### Main #####

clear



checks

prepare_system

download_node

setup_node
