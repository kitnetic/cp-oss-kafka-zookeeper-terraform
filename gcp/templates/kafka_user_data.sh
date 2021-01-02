#!/bin/bash

set -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# workaround for GCP running the startup script on boot
if [ -e "/etc/kafka/kafka_installed.tag" ]; then
    echo "Kafka Install has already run, Exiting"
    exit
fi

# Configure kafka
cat > /etc/kafka/server.properties << "EOF"
# The id of the broker. This must be set to a unique integer for each broker.
broker.id=-1
############################# Socket Server Settings #############################
listeners=PLAINTEXT://:9092
# The number of threads that the server uses for receiving requests from the network and sending responses to the network
num.network.threads=3
# The number of threads that the server uses for processing requests, which may include disk I/O
num.io.threads=8
# The send buffer (SO_SNDBUF) used by the socket server
socket.send.buffer.bytes=102400
# The receive buffer (SO_RCVBUF) used by the socket server
socket.receive.buffer.bytes=102400
# The maximum size of a request that the socket server will accept (protection against OOM)
socket.request.max.bytes=104857600

############################ Log Basics #############################
# A comma separated list of directories under which to store log files
log.dirs=/data/kafka
# The default number of log partitions per topic.
num.partitions=1
# The number of threads per data directory to be used for log recovery at startup and flushing at shutdown.
# This value is recommended to be increased for installations with data dirs located in RAID array.
num.recovery.threads.per.data.dir=1

############################# Log Retention Policy #############################
log.retention.hours=168
#log.retention.bytes=1073741824
# The maximum size of a log segment file. When this size is reached a new log segment will be created.
log.segment.bytes=1073741824
# The interval at which log segments are checked to see if they can be deleted according
# to the retention policies
log.retention.check.interval.ms=300000
############################# Zookeeper #############################
zookeeper.connect=${zookeepers_string}
# Timeout in ms for connecting to zookeeper
zookeeper.connection.timeout.ms=6000
############################# Group Coordinator Settings #############################
# The following configuration specifies the time, in milliseconds, that the GroupCoordinator will delay the initial consumer rebalance.
# However, in production environments the default value of 3 seconds is more suitable as this will help to avoid unnecessary, and potentially expensive, rebalances during application startup.
# group.initial.rebalance.delay.ms=0
EOF

echo "advertised.listeners=PLAINTEXT://$(hostname):9092" >> /etc/kafka/server.properties

cat > /etc/kafka/log4j.properties << "EOF"
log4j.rootLogger=INFO, stdout, kafkaAppender

log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.kafkaAppender=org.apache.log4j.RollingFileAppender
log4j.appender.kafkaAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.kafkaAppender.File=$${kafka.logs.dir}/server.log
log4j.appender.kafkaAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.kafkaAppender.MaxFileSize=100MB
log4j.appender.kafkaAppender.MaxBackupIndex=10
log4j.appender.kafkaAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.stateChangeAppender=org.apache.log4j.RollingFileAppender
log4j.appender.stateChangeAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.stateChangeAppender.File=$${kafka.logs.dir}/state-change.log
log4j.appender.stateChangeAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.stateChangeAppender.MaxFileSize=100MB
log4j.appender.stateChangeAppender.MaxBackupIndex=10
log4j.appender.stateChangeAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.requestAppender=org.apache.log4j.RollingFileAppender
log4j.appender.requestAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.requestAppender.File=$${kafka.logs.dir}/kafka-request.log
log4j.appender.requestAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.requestAppender.MaxFileSize=100MB
log4j.appender.requestAppender.MaxBackupIndex=10
log4j.appender.requestAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.cleanerAppender=org.apache.log4j.RollingFileAppender
log4j.appender.cleanerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.cleanerAppender.File=$${kafka.logs.dir}/log-cleaner.log
log4j.appender.cleanerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.cleanerAppender.MaxFileSize=100MB
log4j.appender.cleanerAppender.MaxBackupIndex=10
log4j.appender.cleanerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.controllerAppender=org.apache.log4j.RollingFileAppender
log4j.appender.controllerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.controllerAppender.File=$${kafka.logs.dir}/controller.log
log4j.appender.controllerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.controllerAppender.MaxFileSize=100MB
log4j.appender.controllerAppender.MaxBackupIndex=10
log4j.appender.controllerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.authorizerAppender=org.apache.log4j.RollingFileAppender
log4j.appender.authorizerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.authorizerAppender.File=$${kafka.logs.dir}/kafka-authorizer.log
log4j.appender.authorizerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.authorizerAppender.MaxFileSize=100MB
log4j.appender.authorizerAppender.MaxBackupIndex=10
log4j.appender.authorizerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

# Change the two lines below to adjust the general broker logging level (output to server.log and stdout)
log4j.logger.kafka=INFO
log4j.logger.org.apache.kafka=INFO

# Change to DEBUG or TRACE to enable request logging
log4j.logger.kafka.request.logger=WARN, requestAppender
log4j.additivity.kafka.request.logger=false

# Uncomment the lines below and change log4j.logger.kafka.network.RequestChannel$ to TRACE for additional output
# related to the handling of requests
# log4j.logger.kafka.network.Processor=TRACE, requestAppender
# log4j.logger.kafka.server.KafkaApis=TRACE, requestAppender
# log4j.additivity.kafka.server.KafkaApis=false
log4j.logger.kafka.network.RequestChannel$=WARN, requestAppender
log4j.additivity.kafka.network.RequestChannel$=false

log4j.logger.kafka.controller=TRACE, controllerAppender
log4j.additivity.kafka.controller=false
log4j.logger.kafka.log.LogCleaner=INFO, cleanerAppender
log4j.additivity.kafka.log.LogCleaner=false
log4j.logger.state.change.logger=TRACE, stateChangeAppender
log4j.additivity.state.change.logger=false
# Access denials are logged at INFO level, change to DEBUG to also log allowed accesses
log4j.logger.kafka.authorizer.logger=INFO, authorizerAppender
log4j.additivity.kafka.authorizer.logger=false
EOF

sudo mkdir -p /data

# setup google cloud logging
sudo mkdir -p /etc/google-fluentd/config.d

cat > /etc/google-fluentd/config.d/kafka.conf << "EOF"
<source>
  @type tail
  format none
  path /var/log/kafka/server.log
  pos_file /var/lib/google-fluentd/pos/kafka-server.pos
  read_from_head true
  tag kafka-server
</source>
<source>
  @type tail
  format none
  path /var/log/kafka/state-change.log
  pos_file /var/lib/google-fluentd/pos/kafka-state.pos
  read_from_head true
  tag kafk-state
</source>
<source>
  @type tail
  format none
  path /var/log/kafka/kafka-request.log
  pos_file /var/lib/google-fluentd/pos/kafka-request.pos
  read_from_head true
  tag kafka-request
</source>
<source>
  @type tail
  format none
  path /var/log/kafka/log-cleaner.log
  pos_file /var/lib/google-fluentd/pos/kafka-cleaner.pos
  read_from_head true
  tag kafka-cleaner
</source>
<source>
  @type tail
  format none
  path /var/log/kafka/controller.log
  pos_file /var/lib/google-fluentd/pos/kafka-controller.pos
  read_from_head true
  tag kafka-controller
</source>
<source>
  @type tail
  format none
  path /var/log/kafka/kafka-authorizer.log
  pos_file /var/lib/google-fluentd/pos/kafka-authorizer.pos
  read_from_head true
  tag kafka-authorizer
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

echo "installed" > /etc/kafka/kafka_installed.tag

sudo mkdir -p /data/kafka

sudo chown -R cp-kafka:confluent /data/kafka

# Enable Zookeeper Auto Restart
sudo systemctl enable confluent-kafka

# Now Start the Zookeeper
sudo systemctl start confluent-kafka
