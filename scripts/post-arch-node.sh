#!/bin/sh

# This file can be downloaded at http://tinyurl.com/oyuh92j
######################################
# To build the sd card, follow instructions @ http://archlinuxarm.org/platforms/armv6/raspberry-pi
# Then run this script.
# After boot, one can log a s `root` (password = `root`)
# And run: `systemctl start slim` to start the window manager
######################################

set -e # stop if any error happens

USER_NAME=node
PASSWORD=node
PSV_DATA_DIR=/psv_results


############# PACKAGES #########################
echo 'Installing and updating packages'

# pacman-db-update
# pacman-key --init
pacman -Syu --noconfirm
pacman -S base-devel git gcc-fortran rsync wget fping --noconfirm --needed

### Video capture related Not needed in Node
#pacman -S opencv mplayer ffmpeg gstreamer gstreamer0.10-plugins mencoder --noconfirm --needed
# a desktop environment may be useful:
pacman -S xorg-server xorg-utils xorg-server-utils xorg-xinit xf86-video-fbdev lxde slim --noconfirm --needed
# utilities
pacman -S ntp bash-completion --noconfirm --needed
pacman -S raspberrypi-firmware{,-tools,-bootloader,-examples} --noconfirm --needed

# preinstalling dependencies will save compiling time on python packages
pacman -S python2-pip python2-numpy python2-bottle python2-pyserial mysql-python python2-netifaces python2-cherrypy --noconfirm --needed

# mariadb
pacman -S mariadb --noconfirm --needed

#setup Wifi dongle
#pacman -S netctl
pacman -S wpa_supplicant --noconfirm --needed

pip2 install python-nmap
pip2 install eventlet

echo 'Description=psv wifi network' >> /etc/netctl/psv_wifi
echo 'Interface=wlan0' >> /etc/netctl/psv_wifi
echo 'Connection=wireless' >> /etc/netctl/psv_wifi
echo 'Security=wpa' >> /etc/netctl/psv_wifi
echo 'IP=dhcp' >> /etc/netctl/psv_wifi
echo 'ESSID=psv_wifi' >> /etc/netctl/psv_wifi
# Prepend hexadecimal keys with \"
# If your key starts with ", write it as '""<key>"'
# See also: the section on special quoting rules in netctl.profile(5)
echo 'Key=PSV_WIFI_pIAEZF2s@jmKH' >> /etc/netctl/psv_wifi
# Uncomment this if your ssid is hidden
#echo 'Hidden=yes'

#
#####################################################################################
echo 'Description=eth0 Network' >> /etc/netctl/eth0
echo 'Interface=eth0' >> /etc/netctl/eth0
echo 'Connection=ethernet' >> /etc/netctl/eth0
echo 'IP=dhcp' >> /etc/netctl/eth0
######################################################################################

#Creating service for device_server.py

cp ./node.service /etc/systemd/system/node.service

systemctl daemon-reload
######################################################################################

######################################################################################
echo 'Enabling startuup deamons'

systemctl disable systemd-networkd
ip link set eth0 down
# Enable networktime protocol
systemctl start ntpd.service
systemctl enable ntpd.service
# Setting up ssh server
systemctl enable sshd.service
systemctl start sshd.service
#setting up wifi
# FIXME this not work if not psv-wifi
netctl start psv_wifi || echo 'No psv_wifi connection'
netctl enable psv_wifi
netctl enable eth0
netctl start eth0

#node service
systemctl start node.service
systemctl enable node.service

# Setting passwordless ssh, this is the content of id_rsa.pub used in git updates.
#TODO do not use a relative path.
mkdir -p /home/$USER_NAME/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKXjWAfHrJ/HAPO3d4vu5s5+Xxw5NDKX1a8rqx3amo0WO7wWe0m2uv+rnJuH7xvWCKMOGlv9jgj1vSSNcuMT30tzioHqRf/k7scUXFPoWxvxTZtqXizZwKe93mfOvCC5Ni5zLtUyMqycnLPGP2K1Rf0Xvx/WLP94bcxXyTaGtftvTcAIC53Kll1XgyHSxsh1ou7rTXt57V0/1wnWqOGH1Y+AMqUkBEKjU2QUZyYoUaVSfwBwSpIi8tvH/Ng5aEH6BGs4cqDnXUBWpdDD6JdR5NxhqYK0lcpWltBlSz8RFvoOKpyQ/0vs5ysNPgX/N4eaHWhECRFD5oNkNXIUBRpe3/ psv@polygonaltree.com
' >> /home/$USER_NAME/.ssh/authorized_keys


#TODOs: locale/TIMEZONE/keyboard ...

##########################################################################################
# add password without stoping
echo 'Creating default user'

pass=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
useradd -m -g users -G wheel -s /bin/bash  -p $pass $USER_NAME || echo 'user exists'

echo 'exec startlxde' >> /home/$USER_NAME/.xinitrc
chown $USER_NAME /home/$USER_NAME/.xinitrc

############################################
echo 'Generating boot config'

echo 'start_file=start_x.elf' > /boot/config.txt
echo 'fixup_file=fixup_x.dat' >> /boot/config.txt
echo 'disable_camera_led=1' >> /boot/config.txt
#gpu_mem_512=64
#gpu_mem_256=64


###Turbo #FIXME NOT needed for piv2.0
#echo 'arm_freq=1000' >> /boot/config.txt
#echo 'core_freq=500' >> /boot/config.txt
#echo 'sdram_freq=500' >> /boot/config.txt
#echo 'over_voltage=6' >> /boot/config.txt

### TODO test, is that enough?
echo 'gpu_mem=256' >>  /boot/config.txt
echo 'cma_lwm=' >>  /boot/config.txt
echo 'cma_hwm=' >>  /boot/config.txt
echo 'cma_offline_start=' >>  /boot/config.txt


echo 'Loading bcm2835 module'

#to use the camera through v4l2
# modprobe bcm2835-v4l2
echo "bcm2835-v4l2" > /etc/modules-load.d/picamera.conf

echo 'Setting permissions for using arduino'
#SEE https://wiki.archlinux.org/index.php/arduino#Configuration
gpasswd -a $USER_NAME uucp
gpasswd -a $USER_NAME lock
gpasswd -a $USER_NAME tty


###########################################################################################
# The hostname is derived from the **eth0** MAC address, NOT the wireless one
#mac_addr=$(ip link show  eth0  |  grep -ioh '[0-9A-F]\{2\}\(:[0-9A-F]\{2\}\)\{5\}' | head -1 | sed s/://g)
# The hostname is derived from the **machine-id**, located in /etc/machine-id

device_id=$(cat /etc/machine-id)
#hostname=PI_$device_id
hostname='node'
echo "Hostname is $hostname"
hostnamectl set-hostname $hostname



#### set the ssd
echo "o
n
p
1



w
" | fdisk /dev/sda

mkfs.ext4 /dev/sda1
mkdir -p $PSV_DATA_DIR
chmod 744 $PSV_DATA_DIR -R
mount /dev/sda1 $PSV_DATA_DIR
cp /etc/fstab /etc/fstab-bak
echo "/dev/sda1 $PSV_DATA_DIR ext4 defaults,rw,relatime,data=ordered 0 1" >> /etc/fstab












#Create a Bare repository with only the production branch in node, it is on /var/
git clone --bare -b psv-package --single-branch https://github.com/gilestrolab/pySolo-Video.git /var/pySolo-Video.git
#Create a local working copy from the bare repo on node
git clone /var/pySolo-Video.git /home/$USER_NAME/pySolo-Video

# our software.
# TODO use AUR!
echo 'Installing PSV package'
#wget hthttp://stackoverflow.com/questions/758819/python-mysqldb-connection-problemstps://github.com/gilestrolab/pySolo-Video/archive/psv_prerelease.tar.gz -O psv.tar.gz
#tar -xvf psv.tar.gz
cd /home/node/pySolo-Video/psvnode_server
pip2 install -e .

echo 'SUCESS, please reboot'
