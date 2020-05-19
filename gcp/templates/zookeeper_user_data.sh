#!/bin/bash

set -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# workaround for GCP running the startup script on boot
if [ -e "/data/myid" ]; then
    echo "Myid file found, Zookeeper Install has already run, Exiting"
    exit
fi



# Configure zookeper
cat <<'EOF' >>/etc/kafka/zookeeper.properties
reconfigEnabled=false
4lw.commands.whitelist=srvr, mntr

%{ for zkId in allZookeeperIds ~}
server.${zkId}=${host_name_base}-${zkId}:2888:3888;2181
%{ endfor ~}

EOF

# Configure zookeeper logging
sudo mkdir -p /var/log/zookeeper
sudo chown -R cp-kafka:confluent /var/log/zookeeper
cat > /etc/kafka/log4j.properties << "EOF"
log4j.rootLogger=INFO, CONSOLE
#
# console
# Add "console" to rootlogger above if you want to use this
#
log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender
log4j.appender.CONSOLE.Threshold=INFO
log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout
log4j.appender.CONSOLE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n
#
# Add ROLLINGFILE to rootLogger to get log file output
#
log4j.appender.ROLLINGFILE=org.apache.log4j.RollingFileAppender
log4j.appender.ROLLINGFILE.Threshold=INFO
log4j.appender.ROLLINGFILE.File=/var/log/zookeeper/zookeeper.log
log4j.appender.ROLLINGFILE.MaxFileSize=100MB
log4j.appender.ROLLINGFILE.MaxBackupIndex=20
log4j.appender.ROLLINGFILE.layout=org.apache.log4j.PatternLayout
log4j.appender.ROLLINGFILE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n
#
# Add TRACEFILE to rootLogger to get log file output
#    Log TRACE level and above messages to a log file
#
log4j.appender.TRACEFILE=org.apache.log4j.RollingFileAppender
log4j.appender.TRACEFILE.Threshold=TRACE
log4j.appender.TRACEFILE.File=/var/log/zookeeper/zookeeper_trace.log
log4j.appender.TRACEFILE.layout=org.apache.log4j.PatternLayout
log4j.appender.TRACEFILE.MaxFileSize=100MB
log4j.appender.TRACEFILE.MaxBackupIndex=20
### Notice we are including log4j's NDC here (%x)
log4j.appender.TRACEFILE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L][%x] - %m%n
EOF

sudo mkdir -p /data

# setup google cloud logging
sudo mkdir -p /etc/google-fluentd/config.d

cat > /etc/google-fluentd/config.d/zookeeper.conf << "EOF"
<source>
  @type tail
  format none
  path /var/log/zookeeper/zookeeper.log
  pos_file /var/lib/google-fluentd/pos/zookeeper.pos
  read_from_head true
  tag zookeeper
</source>

<source>
  @type tail
  format none
  path /var/log/zookeeper/zookeeper_trace.log
  pos_file /var/lib/google-fluentd/pos/zookeeper-trace.pos
  read_from_head true
  tag zookeeper-trace
</source>
EOF

cat > /etc/google-fluentd/config.d/syslog.conf << "EOF"
<source>
  @type tail

  # Parse the timestamp, but still collect the entire line as 'message'
  format /^(?<message>(?<time>[^ ]*\s*[^ ]* [^ ]*) .*)$/

  path /var/log/syslog
  pos_file /var/lib/google-fluentd/pos/syslog.pos
  read_from_head true
  tag syslog
</source>
EOF

cat > /etc/google-fluentd/config.d/syslog_endpoint.conf << "EOF"
<source>
  @type syslog
  port 514
  protocol_type udp
  bind 127.0.0.1
  format /(?<message>.*)/
  tag syslog
</source>
<source>
  @type syslog
  port 514
  protocol_type tcp
  bind 127.0.0.1
  format /(?<message>.*)/
  tag syslog
</source>
EOF

service google-fluentd restart

# Mount data disk
echo 'about to mount disk'
export DEVICE_NAME=$(lsblk -ip | tail -n +2 | grep -v " rom" | awk '{print $1 " " ($7? "MOUNTEDPART" : "") }' | sed ':a;N;$!ba;s/\n`/ /g' | sed ':a;N;$!ba;s/\n|-/ /g' | grep -v MOUNTEDPART)
# export DEVICE_NAME=$(lsblk -ip | tail -n +2 | grep -v " rom" | awk '{print $1 " " ($7? "MOUNTEDPART" : "") }' | sed ':a;N;$!ba;s/\n`/ /g' | grep -v MOUNTEDPART)
# from es-aws-6  export DEVICE_NAME=$(lsblk -ip | tail -n +2 | awk '{print $1 " " ($7? "MOUNTEDPART" : "") }' | sed ':a;N;$!ba;s/\n`/ /g' | grep -v MOUNTEDPART)
if sudo mount -o defaults -t ext4 $${DEVICE_NAME} /data; then
    echo 'Successfully mounted existing disk'
else
    echo 'Trying to mount a fresh disk'
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard $${DEVICE_NAME}
    sudo mount -o defaults -t ext4 $${DEVICE_NAME} /data && echo 'Successfully mounted a fresh disk'
fi
echo "$$DEVICE_NAME /data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

#  Write myid file
zookeeper_hostname=`hostname`

echo $${zookeeper_hostname#*${host_name_base}-} > /data/myid

sudo chown -R cp-kafka:confluent /data

# Enable Zookeeper Auto Restart
sudo systemctl enable confluent-zookeeper

# Now Start the Zookeeper
sudo systemctl start confluent-zookeeper
