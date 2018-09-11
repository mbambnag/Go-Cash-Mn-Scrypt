#!/bin/bash
clear

# Set these to change the version of Go Cash to install
TARBALLURL="https://github.com/mbambnag/GoCash-Core/releases/download/v.1.1.1.5/linux-cli1.5.tar.gz"
TARBALLNAME="linux-cli1.5.tar.gz"
VERSION="1.1.5"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
clear

echo "
 +-------------- MASTERNODE INSTALLER v1.0 -------+
 |                                                |
 |You can choose between two installation options:|::
 |             default and advanced.              |::
 |                                                |::
 | The advanced installation will install and run |::
 |  the masternode under a non-root user. If you  |::
 |  don't know what that means, use the default   |::
 |              installation method.              |::
 |                                                |::
 | Otherwise, your masternode will not work, and  |::
 |the Go Cash Team CANNOT assist you in repairing  |::
 |        it. You will have to start over.        |::
 |                 Go Cash $VERSION                |::
 |Don't use the advanced option unless you are an |::
 |            experienced Linux user.             |::
 |                                                |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::
"

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=gocash

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

echo "" && echo 'Added user "gocash"' && echo ""
sleep 1

else

USER=root

fi

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 69SvmzwKYzUhGsQAwiah1gAYXD2HBRbQyg2SpZ4j4MZzct75jqK # THE KEY YOU GENERATED EARLIER) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget git htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install libevent-pthreads-2.0-5 && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 2579/tcp
  yes | ufw enable
fi
#rm $TARBALLNAME
# Install Go Cash daemon
wget $TARBALLURL && tar -xzvf $TARBALLNAME && cd gocash-$VERSION/bin && cp ./gocashd /usr/local/bin && cp ./gocash-cli /usr/local/bin && cd /root && rm -rf gocash-$VERSION
#cp ./gocash-tx /usr/local/bin
#cp ./gocash-qt /usr/local/bin
#rm -rf gocash-$VERSION

# Create .gocash directory
mkdir $USERHOME/.gocash

# Install bootstrap file
#if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
#  echo "Installing bootstrap file..."
#  wget $BOOTSTRAPURL && unzip $BOOTSTRAPARCHIVE -d $USERHOME/.gocash/ && rm $BOOTSTRAPARCHIVE
#fi

# Create gocash.conf
touch $USERHOME/.gocash/gocash.conf
cat > $USERHOME/.gocash/gocash.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:9911
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1

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
EOL
chmod 0600 $USERHOME/.gocash/gocash.conf
chown -R $USER:$USER $USERHOME/.gocash

sleep 1

cat > /etc/systemd/system/gocashd.service << EOL
[Unit]
Description=gocashd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/gocashd -conf=${USERHOME}/.gocash/gocash.conf -datadir=${USERHOME}/.gocash
ExecStop=/usr/local/bin/gocash-cli -conf=${USERHOME}/.gocash/gocash.conf -datadir=${USERHOME}/.gocash stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable gocashd
sudo systemctl start gocashd
sudo systemctl start gocashd.service

#clear

#clear
#echo "Your masternode is syncing. Please wait for this process to finish."

until su -c "gocash-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 5
    #echo -en "${CHARS:$i:1}" "\r"
    clear
    echo "Service Started. Your masternode is syncing.
    When Current = Synced then select your MN in the local wallet and start it.
    Script should auto finish here."
    echo "
    Current Block: "
    su -c "curl http://66.42.52.30:3001/api/getblockcount" $USER
    echo "
    Synced Blocks: "
    su -c "gocash-cli getblockcount" $USER
  done
done

#echo "Your masternode is syncing. Please wait for this process to finish."
#echo "CTRL+C to exit the masternode sync once you see the MN ENABLED in your local wallet." && echo ""

#until su -c "gocash-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
#  for (( i=0; i<${#CHARS}; i++ )); do
#    sleep 2
#    echo -en "${CHARS:$i:1}" "\r"
#  done
#done

sleep 1
su -c "/usr/local/bin/gocash-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/gocash-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""