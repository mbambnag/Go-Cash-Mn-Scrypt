#!/bin/bash

echo "Updating linux packages"
sudo apt-get update && sudo apt-get upgrade -y

echo "Intalling screen"
sudo apt install screen -y

echo "Installing git"
sudo apt install git -y

echo "Installing curl"
sudo apt install curl -y

echo "Intalling fail2ban"
sudo apt install fail2ban -y

echo "Installing Firewall"
sudo apt install ufw -y
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh/tcp
sudo ufw limit ssh/tcp
sudo ufw allow 9911/tcp
sudo ufw logging on
sudo ufw --force enable

echo "Installing PWGEN"
sudo apt-get install -y pwgen

echo "Installing Dependencies"
sudo apt-get --assume-yes install git unzip build-essential libssl-dev libdb++-dev libboost-all-dev libcrypto++-dev libqrencode-dev libminiupnpc-dev libgmp-dev libgmp3-dev autoconf libevent-dev autogen automake  libtool

echo "Downloading GoCash Wallet"
wget https://github.com/mbambnag/GoCash-Core/releases/download/v.1.1.1.5/linux-cli1.5.tar.gz
sudo tar -xvf linux-cli1.5.tar.gz -C /usr/local/bin
sudo mv /usr/local/bin/linux-cli1.5 /usr/local/bin/gocashd
rm linux-cli1.5.tar.gz

#echo "Installing GoCash Wallet"
#git clone https://github.com/carsenk/gocash
#cd gocash
#git checkout master
#cd src
#make -f makefile.unix

echo "Populate gocash.conf"
    mkdir  ~/.gocash
    # Get VPS IP Address
    VPSIP=$(curl ipinfo.io/ip)
    # create rpc user and password
    rpcuser=$(openssl rand -base64 24)
    # create rpc password
    rpcpassword=$(openssl rand -base64 48)
    echo -n "What is your masternodeprivkey? (Hint:genkey output)"
    read MASTERNODEPRIVKEY
    echo -e "rpcuser=$rpcuser\nrpcpassword=$rpcpassword\naddnode=45.76.251.234:9911\naddnode=46.33.239.29:9911\naddnode=115.178.211.116:9911\naddnode=gocash.host\naddnode=hashbag.cc\nserver=1\nlisten=1\nmaxconnections=100\ndaemon=1\nport=9911\nstaking=0\nrpcallowip=127.0.0.1\nexternalip=$VPSIP:9911\nmasternode=1\nmasternodeprivkey=$MASTERNODEPRIVKEY" > ~/.gocash/gocash.conf


echo "Starting GoCash Daemon"
gocashd --daemon
#echo "Run ./gocashd"
#screen -dmS gocashd /gocash/src/./gocashd

echo "Setting auto start cron job for gocashd"
cronjob="@reboot sleep 30 && /usr/local/bin/gocashd -daemon >/dev/null 2>&1"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then
    echo -e "Configuring crontab job..."
    echo $cronjob >> tempcron
    crontab tempcron
fi
rm tempcron

# echo "Removing Root Login Access"
# Disable root login
echo "to remove root login access type line below"
echo "sudo sed -i '/^PermitRootLogin[ \t]\+\w\+$/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config"
