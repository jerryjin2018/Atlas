#!/bin/sh
. /etc/profile
. ~/.bash_profile

#create folder for installation
echo "###### install-1 ######"
sudo mkdir /apache && sudo chown hadoop.hadoop /apache

#download file
echo "###### install-2 ######"
sudo curl https://s3.amazonaws.com/apache-atlas-setup-on-emr/apache-atlas-1.0.0-bin.tar.gz -o /tmp/apache-atlas-1.0.0-bin.tar.gz && sudo tar xvpfz /tmp/apache-atlas-1.0.0-bin.tar.gz -C /apache
sudo curl https://s3.amazonaws.com/apache-atlas-setup-on-emr/kafka_2.11-1.1.0.tgz -o /tmp/kafka_2.11-1.1.0.tgz && sudo tar xvpfz /tmp/kafka_2.11-1.1.0.tgz -C /apache
sudo yum install -y https://s3.amazonaws.com/apache-atlas-setup-on-emr/jdk-8u171-linux-x64.rpm

# Create symlinks
echo "###### install-3 ######"
sudo ln -s /apache/kafka_2.11-1.1.0 /apache/kafka
sudo ln -s /apache/apache-atlas-1.0.0 /apache/atlas

# Change default port for zookeeper and kafka
echo "###### install-4 ######"
sudo sed -i 's/clientPort=2181/clientPort=3000/' /apache/kafka/config/zookeeper.properties
sudo sed -i 's/zookeeper.connect=localhost:2181/zookeeper.connect=localhost:3000/' /apache/kafka/config/server.properties

#set these variables in hadoop user's bash profile
echo "###### install-5 ######"
sudo cat << EOL >> /home/hadoop/.bash_profile
export JAVA_HOME=/usr/java/jdk1.8.0_171-amd64/
export MANAGE_LOCAL_HBASE=false
export MANAGE_LOCAL_SOLR=true
export HIVE_HOME=/usr/lib/hive
export HIVE_CONF_DIR=/usr/lib/hive/conf
EOL

echo "###### install-6 ######"
export JAVA_HOME=/usr/java/jdk1.8.0_171-amd64/
sudo /apache/kafka/bin/zookeeper-server-start.sh -daemon /apache/kafka/config/zookeeper.properties
sudo /apache/kafka/bin/kafka-server-start.sh -daemon /apache/kafka/config/server.properties

# Create a symlink in native hive's conf directory
echo "###### install-7 ######"
sudo ln -s /apache/atlas/conf/atlas-application.properties /usr/lib/hive/conf/atlas-application.properties

# add hive hook in /etc/hive/conf/hive-site.xml
# Ensure that following is present:
#  <property>
#    <name>hive.exec.post.hooks</name>
#    <value>org.apache.atlas.hive.hook.HiveHook</value>
#  </property>
echo "###### install-8 ######"
sudo cp /etc/hive/conf/hive-site.xml /etc/hive/conf/hive-site.xml.orig
sudo sed -i "s#</configuration>#   <property>\n     <name>hive.exec.post.hooks</name>\n     <value>org.apache.atlas.hive.hook.HiveHook</value>\n   </property>\n\n</configuration>#" /etc/hive/conf/hive-site.xml || mv /etc/hive/conf/hive-site.xml.orig /etc/hive/conf/hive-site.xml

# Create symlinks to the jar files under atlas folder
echo "###### install-8 ######"
cd /usr/lib/hive/lib
sudo ln -s /apache/atlas/hook/hive/atlas-plugin-classloader-1.0.0.jar
sudo ln -s /apache/atlas/hook/hive/hive-bridge-shim-1.0.0.jar
for i in /apache/atlas/hook/hive/atlas-hive-plugin-impl/*; do sudo ln -s $i; done

# Restart hive server
echo "###### install-9 ######"
export HIVE_HOME=/usr/lib/hive
export HIVE_CONF_DIR=/usr/lib/hive/conf
sudo systemctl stop hive-server2.service 
sudo systemctl start hive-server2.service 
sudo systemctl status hive-server2.service 

# To run Apache Atlas with local Apache HBase & Apache Solr instances that are started/stopped along with Atlas start/stop, run following commands:
echo "###### install-10 ######"
sudo sed -i 's?#export JAVA_HOME=?export JAVA_HOME=/usr/java/jdk1.8.0_171-amd64?' /apache/atlas/conf/atlas-env.sh
sudo sed -i 's/export MANAGE_LOCAL_HBASE=true/export MANAGE_LOCAL_HBASE=false/' /apache/atlas/conf/atlas-env.sh
sudo /apache/atlas/bin/atlas_stop.py && sudo /apache/atlas/bin/atlas_start.py
