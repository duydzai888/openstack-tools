#!/bin/bash
#Author HOC CHU DONG

source function.sh
source config.cfg

function config_hostname () {

hostnamect set-hostname $CTL1_HOSTNAME

echo "127.0.0.1 locahost $CTL1_HOSTNAME" > /etc/hosts
echo "$CTL1_IP_NIC2 $CTL1_HOSTNAME" >> /etc/hosts
echo "$COM1_IP_NIC2 $COM1_HOSTNAME" >> /etc/hosts
echo "$COM2_IP_NIC2 $COM2_HOSTNAME" >> /etc/hosts
echo "$CINDER1_IP_NIC2 $CINDER1_HOSTNAME" >> /etc/hosts
}


# Function update and upgrade for CONTROLLER
function update_upgrade () {
	echocolor "Update and Update controller"
	sleep 3
	apt-get update -y&& apt-get upgrade -y
}

# Function install and config NTP
function install_ntp () {
	echocolor "Install NTP"
	sleep 3

	apt-get install chrony -y 2>&1 | tee -a filelog-install.txt
	ntpfile=/etc/chrony/chrony.conf

	sed -i 's/pool 2.debian.pool.ntp.org offline iburst/ \
pool 2.debian.pool.ntp.org offline iburst \
server 0.asia.pool.ntp.org iburst \
server 1.asia.pool.ntp.org iburst/g' $ntpfile

	echo "allow 172.16.70.212/24" >> $ntpfile

	service chrony restart 2>&1 | tee -a filelog-install.txt
}

# Function install OpenStack packages (python-openstackclient)
function install_ops_packages () {
	echocolor "Install OpenStack client"
	sleep 3
	sudo apt-get install software-properties-common -y 2>&1 | tee -a filelog-install.txt
  sudo add-apt-repository cloud-archive:wallaby -y 2>&1 | tee -a filelog-install.txt
  sudo apt-get update -y 2>&1 | tee -a filelog-install.txt
  sudo apt-get upgrade -y 2>&1 | tee -a filelog-install.txt
  sudo apt-get install python-openstackclient -y 2>&1 | tee -a filelog-install.txt
}

function install_database() {
	echocolor "Install and Config MariaDB"
	sleep 3

	echo mariadb-server-10.0 mysql-server/root_password $PASS_DATABASE_ROOT | debconf-set-selections
	echo mariadb-server-10.0 mysql-server/root_password_again $PASS_DATABASE_ROOT | debconf-set-selections

	sudo apt install mariadb-server python3-pymysql -y 2>&1 | tee -a filelog-install.txt


	sed -r -i 's/127\.0\.0\.1/0\.0\.0\.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
	sed -i 's/character-set-server  = utf8mb4/character-set-server  = utf8/' /etc/mysql/mariadb.conf.d/50-server.cnf
	sed -i 's/collation-server/#collation-server/' /etc/mysql/mariadb.conf.d/50-server.cnf

	systemctl restart mysql

cat << EOF | mysql -uroot -p$PASS_DATABASE_ROOT 
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$PASS_DATABASE_ROOT' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$PASS_DATABASE_ROOT' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

	sqlfile=/etc/mysql/mariadb.conf.d/99-openstack.cnf
	touch $sqlfile	
	ops_add $sqlfile client default-character-set utf8
	ops_add $sqlfile mysqld bind-address 0.0.0.0
	ops_add $sqlfile mysqld default-storage-engine innodb
	ops_add $sqlfile mysqld innodb_file_per_table
	ops_add $sqlfile mysqld max_connections 4096
	ops_add $sqlfile mysqld collation-server utf8_general_ci
	ops_add $sqlfile mysqld character-set-server utf8

	echocolor "Restarting MYSQL"
	sleep 5
	systemctl restart mysql

}


# Function install message queue
function install_mq () {
	echocolor "Install Message queue (rabbitmq)"
	sleep 3

	sudo apt -y install rabbitmq-server memcached python3-pymysql
	rabbitmqctl add_user openstack $RABBIT_PASS
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"
}

# Function install Memcached
function install_memcached () {
	echocolor "Install Memcached"
	sleep 3

	apt-get install memcached python3-memcache -y
	memcachefile=/etc/memcached.conf
	sed -i 's|-l 127.0.0.1|'"-l $CTL1_IP_NIC2"'|g' $memcachefile

	systemctl restart mariadb rabbitmq-server memcached 2>&1 | tee -a filelog-install.txt
} 

#######################
###Execute functions###
#######################

sendtelegram "Thuc thi script $0 tren `hostname`"

sendtelegram "config_hostname `hostname`"
config_hostname

# Update and upgrade for controller
sendtelegram "Update OS tren `hostname`"
update_upgrade

# Install and config NTP
sendtelegram "Cai dat NTP tren `hostname`"
install_ntp

# OpenStack packages (python-openstackclient)
sendtelegram "Cai dat install_ops_packages tren `hostname`"
install_ops_packages

# Install SQL database (Mariadb)
sendtelegram "Cai dat install_database tren `hostname`"
install_database

# Install Message queue (rabbitmq)
sendtelegram "Cai dat install_mq tren `hostname`"
install_mq

# Install Memcached
sendtelegram "Cai dat install_memcached tren `hostname`"
install_memcached

sendtelegram "Da hoa thanh $0 `hostname`"
notify