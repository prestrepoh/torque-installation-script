#!/bin/bash -x 
# install_torque.sh: This script installs torque on master node and compute nodes in a Linux Rocks 6.0 Installation.
# Juan Pineda <jpineda2@eafit.edu.co>
# John Gutierrez <jgutie39@eafit.edu.co>
# 28/6/2013
# Centro de Computación Científica APOLO
# Universidad EAFIT
# http://www.eafit.edu.co
# Medellín - Colombia
# 2013

#TODO: Test the existence of every file and every folder on the file system

set -e 
# =============================================
# =============================================
# Install Torque on Master Node
# =============================================
# =============================================
TORQUE_DIR=/var/spool/torque
TMP_DIR=/tmp
cd $TMP_DIR

#TODO: Verify the exit of the following commands. What if galois is down?
#TODO: Fix the torque version dependencies. It not must to be the 4.2.3.
# Downloading and configuring torque.
wget http://galois.eafit.edu.co/apolosrc/6.1/torque/torque-4.2.6.tar.gz >> $TMP_DIR/log_torque.txt 2>&1
wget http://galois.eafit.edu.co/apolosrc/6.1/torque/policies.txt >> $TMP_DIR/log_torque.txt 2>&1
tar xzvf torque-4.2.6.tar.gz >> $TMP_DIR/log_torque.txt 2>&1
cd $TMP_DIR/torque-4.2.6/
echo "Configuring Torque..."
./configure >> $TMP_DIR/log_torque.txt 2>&1

# Compiling torque 
echo "Compiling Torque's source files"
make >> $TMP_DIR/log_torque.txt 2>&1
echo "Installing Torque"
make install >> $TMP_DIR/log_torque.txt 2>&1
echo "Master installation finished"

echo "Adding nodes to the config file..."
# add the compute nodes to the torque config file
rocks run host hostname >> $TORQUE_DIR/server_priv/nodes
# Preparar archivo de configuracion de los nodos
PBSSERVER=$(hostname | cut -d '.' -f1)
echo "\$pbsserver     $PBSSERVER" >> $TORQUE_DIR/mom_priv/config
echo "\$logevent      225" >> $TORQUE_DIR/mom_priv/config

# Enable torque as a service
echo "Enabling Torque Auth Daemon as a service"
cp -rf contrib/init.d/trqauthd /etc/init.d/
chkconfig --add trqauthd
echo '/usr/local/lib' > /etc/ld.so.conf.d/torque.conf  
ldconfig
service trqauthd start

echo "Enabling pbs_server as a service"

cp -rf contrib/init.d/pbs_server /etc/init.d/pbs_server
chkconfig --add pbs_server

echo "Creating queues and policies"

set +e
yes | pbs_server -t create >> $TMP_DIR/log_torque.txt 2>&1
pbs_server
qmgr < ../policies.txt >> $TMP_DIR/log_torque.txt 2>&1
set -e
qstat -q
# Reiniciar pbs_server
qterm
pbs_server


# =============================================
# =============================================
# Install Torque into Compute Nodes
# =============================================
# =============================================
echo "Installing torque in the compute nodes..."
echo "Making installers for the compute nodes"
make packages >> $TMP_DIR/log_torque.txt 2>&1

mkdir -p /export/apps/Torque

cp torque-package-clients-linux-x86_64.sh /export/apps/Torque
cp torque-package-mom-linux-x86_64.sh /export/apps/Torque

rocks run host "/share/apps/Torque/torque-package-clients-linux-x86_64.sh --install" >> $TMP_DIR/log_torque.txt 2>&1
rocks run host "/share/apps/Torque/torque-package-mom-linux-x86_64.sh --install" >> $TMP_DIR/log_torque.txt 2>&1

rocks run host "echo '/usr/local/lib' > /etc/ld.so.conf.d/torque.conf"
rocks run host "ldconfig"


# Copy the config file into the compute nodes
cp $TORQUE_DIR/mom_priv/config /export/apps/Torque
rocks run host "cp /share/apps/Torque/config /var/spool/torque/mom_priv/"

# Copy the daemon script to services
cp contrib/init.d/pbs_mom /export/apps/Torque
rocks run host "cp /share/apps/Torque/pbs_mom /etc/init.d/"
rocks run host "chkconfig --add pbs_mom"

# Restart the service into each compute node
rocks run host "service pbs_mom restart"

echo "Torque installation completed"
cd ..

# =============================================
# =============================================
# Install Maui
# =============================================
# =============================================

echo "Installing Maui..."
MAUI_DIR=/usr/local

wget http://galois.eafit.edu.co/apolosrc/6.1/torque/maui-3.3.1.tar.gz >> $TMP_DIR/log_maui.txt 2>&1
tar xvzf maui-3.3.1.tar.gz >> $TMP_DIR/log_maui.txt 2>&1
cd maui-3.3.1/
echo "Configuring maui..."
./configure >> $TMP_DIR/log_maui.txt 2>&1
echo "Compiling Maui's source files"
make >> $TMP_DIR/log_maui.txt 2>&1
echo "Installing Maui"
make install >> $TMP_DIR/log_maui.txt 2>&1

# Download from galois the service file of maui with wgest.
echo "Installing maui as a service"
wget http://galois.eafit.edu.co/apolosrc/6.0/tools/torque+maui/scripts/maui  >> $TMP_DIR/log_maui.txt 2>&1
cp -rf maui /etc/init.d/
chmod 755 /etc/init.d/maui
chkconfig --add maui
ldconfig
service maui start

echo "Configuring maui"

# APOLO Maui Configuration
echo "# APOLO Maui Configuration"
echo "ADMIN3                ALL" >> $MAUI_DIR/maui/maui.cfg
echo "QOSWEIGHT 1" >> $MAUI_DIR/maui/maui.cfg
echo "CREDWEIGHT 1" >> $MAUI_DIR/maui/maui.cfg
echo "QOSCFG[low] PRIORITY=-10000" >> $MAUI_DIR/maui/maui.cfg
echo "QOSCFG[high] PRIORITY=1000000" >> $MAUI_DIR/maui/maui.cfg
echo "CLASSCFG[standby]       QDEF=low QFLAGS=PREEMPTEE" >> $MAUI_DIR/maui/maui.cfg
echo "CLASSCFG[longjobs]      QDEF=low" >> $MAUI_DIR/maui/maui.cfg
echo "CLASSCFG[mechanics]      QDEF=high QFLAGS=PREEMPTOR" >> $MAUI_DIR/maui/maui.cfg
echo "CLASSCFG[purdue]      QDEF=high QFLAGS=PREEMPTOR" >> $MAUI_DIR/maui/maui.cfg

#TODO: Buggy reloading of the PATH. Fix it!!! This doesn't work until you logout from the console.
echo "export PATH=/usr/local/maui/bin:\$PATH" >> ~/.bash_profile
. ~/.bash_profile
export PATH=/usr/local/maui/bin:$PATH
echo "Finished Succesfully"