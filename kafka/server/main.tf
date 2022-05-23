resource "null_resource" "shell" {
  provisioner "remote-exec" {
    inline = [
      # install wget
      "sudo yum install wget -y",
      # install java
      "sudo yum install java-11-devel -y",
      # set environment hosts file
      "sudo cp /etc/hosts /etc/hosts_backup",
      "echo '${var.host} kafka.local' | sudo tee -a /etc/hosts",
      # setup number of open files limited in Linux
      "echo \"* hard nofile 100000\" | sudo tee --append /etc/security/limits.conf",
      "echo \"* soft nofile 100000\" | sudo tee --append /etc/security/limits.conf",
      # create user kafka
      "sudo adduser --system --no-create-home kafka",
      "sudo usermod -aG wheel kafka",
      # create directory and download kafka
      "sudo mkdir -p /opt/kafka && cd /opt/kafka",
      "sudo wget \"https://dlcdn.apache.org/kafka/3.0.0/kafka_2.13-3.0.0.tgz\" -O kafka.tgz --no-check-certificate",
      "sudo tar -xvf kafka.tgz",
      "sudo rm -rf kafka.tgz",
      "sudo mv kafka_* kafka",
      "sudo mkdir -p /opt/kafka/data/zookeeper",
      "sudo mkdir -p /opt/kafka/data/kafka-logs",
      "sudo mkdir -p /opt/kafka/kafka/logs",
      # setup zookeeper id
      "cat <<EOF > /$HOME/myid",
      "${var.server_id}",
      "EOF",
      "sudo cp /$HOME/myid /opt/kafka/data/zookeeper/myid",
      # config zookeeper user
      "cat <<EOF > /$HOME/zk_server_jaas.conf",
      "Server {",
      "    org.apache.zookeeper.server.auth.DigestLoginModule required",
      "    user_zkclient=\"zkP@ssw0rd\";",
      "};",
      "EOF",
      "sudo cp /$HOME/zk_server_jaas.conf /opt/kafka/kafka/config/zk_server_jaas.conf",
      # config zookeeper
      "cat <<EOF > /$HOME/zookeeper.properties",
      "dataDir=/opt/kafka/data/zookeeper",
      "clientPort=2181",
      "maxClientCnxns=0",
      "admin.enableServer=false",
      "tickTime=2000",
      "initLimit=5",
      "syncLimit=2",
      "requireClientAuthScheme=sasl",
      "authProvider.sasl=org.apache.zookeeper.server.auth.SASLAuthenticationProvider",
      "EOF",
      "sudo cp /opt/kafka/kafka/config/zookeeper.properties /opt/kafka/kafka/config/zookeeper_backup.properties",
      "sudo cp /$HOME/zookeeper.properties /opt/kafka/kafka/config/zookeeper.properties",
      "sudo chown -R kafka:kafka /opt/kafka",
      # create zookeeper service
      "cat <<EOF > /$HOME/zookeeper.service",
      "[Unit]",
      "Description=Apache Zookeeper server (Kafka)",
      "Documentation=http://zookeeper.apache.org",
      "Requires=network.target remote-fs.target",
      "After=network.target remote-fs.target",
      "[Service]",
      "Type=simple",
      "User=kafka",
      "Group=kafka",
      "Environment=JAVA_HOME=/usr/lib/jvm/java-11",
      "Environment=KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/kafka/config/zk_server_jaas.conf",
      "ExecStart=/bin/sh -c '/opt/kafka/kafka/bin/zookeeper-server-start.sh /opt/kafka/kafka/config/zookeeper.properties > /opt/kafka/kafka/logs/zookeeper.log 2>&1'",
      "ExecStop=/opt/kafka/kafka/bin/zookeeper-server-stop.sh",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo cp /$HOME/zookeeper.service /etc/systemd/system/zookeeper.service",
      # start zookeeper
      "sudo systemctl daemon-reload",
      "sudo systemctl enable zookeeper",
      "sudo service zookeeper start",
      # create kafka user on one server
      "sudo /opt/kafka/kafka/bin/kafka-configs.sh --zookeeper ${var.host}:2181 --alter --add-config 'SCRAM-SHA-512=[password=adP@ssw0rd]' --entity-type users --entity-name admin",
      # config kafka user
      "cat <<EOF > /$HOME/kafka_server_jaas.conf",
      "KafkaServer {",
      "    org.apache.kafka.common.security.scram.ScramLoginModule required",
      "    username=\"admin\"",
      "    password=\"adP@ssw0rd\";",
      "};",
      "Client {",
      "    org.apache.zookeeper.server.auth.DigestLoginModule required",
      "    username=\"zkclient\"",
      "    password=\"zkP@ssw0rd\";",
      "};",
      "EOF",
      "sudo cp /$HOME/kafka_server_jaas.conf /opt/kafka/kafka/config/kafka_server_jaas.conf",
      # config kafka client
      "cat <<EOF > /$HOME/client.properties",
      "security.protocol=SASL_SSL",
      "ssl.endpoint.identification.algorithm=",
      "ssl.truststore.location=/opt/kafka/keys/truststore.jks",
      "ssl.truststore.password=3mIuL23PzcRVwQBHoVUV",
      "ssl.keystore.location=/opt/kafka/keys/keystore.jks",
      "ssl.keystore.password=3mIuL23PzcRVwQBHoVUV",
      "sasl.mechanism=SCRAM-SHA-512",
      "sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \\",
      "        username=\"admin\" \\",
      "        password=\"adP@ssw0rd\";",
      "EOF",
      "sudo cp /$HOME/client.properties /opt/kafka/kafka/config/client.properties",
      # config kafka
      "cat <<EOF > /$HOME/server.properties",
      "broker.id=${var.server_id}",
      "listeners=SASL_SSL://:9092",
      "advertised.listeners=SASL_SSL://${var.host}:9092",
      "num.network.threads=3",
      "num.io.threads=8",
      "socket.send.buffer.bytes=102400",
      "socket.receive.buffer.bytes=102400",
      "socket.request.max.bytes=104857600",
      "log.dirs=/opt/kafka/data/kafka-logs",
      "num.partitions=1",
      "num.recovery.threads.per.data.dir=1",
      "offsets.topic.replication.factor=1",
      "transaction.state.log.replication.factor=1",
      "transaction.state.log.min.isr=1",
      "log.retention.hours=168",
      "log.segment.bytes=1073741824",
      "log.retention.check.interval.ms=300000",
      "zookeeper.connect=${var.host}:2181",
      "zookeeper.connection.timeout.ms=18000",
      "group.initial.rebalance.delay.ms=0",
      # "auto.create.topics.enable=false",
      "delete.topic.enable=true",
      "security.inter.broker.protocol=SASL_SSL",
      "ssl.keystore.location=/opt/kafka/keys/keystore.jks",
      "ssl.keystore.password=3mIuL23PzcRVwQBHoVUV",
      "ssl.key.password=3mIuL23PzcRVwQBHoVUV",
      "ssl.truststore.location=/opt/kafka/keys/truststore.jks",
      "ssl.truststore.password=3mIuL23PzcRVwQBHoVUV",
      "sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512",
      "sasl.enabled.mechanisms=SCRAM-SHA-512",
      "authorizer.class.name=kafka.security.authorizer.AclAuthorizer",
      "allow.everyone.if.no.acl.found=false",
      "super.users=User:admin",
      # "zookeeper.set.acl=true",
      "EOF",
      "sudo cp /opt/kafka/kafka/config/server.properties /opt/kafka/kafka/config/server_backup.properties",
      "sudo cp /$HOME/server.properties /opt/kafka/kafka/config/server.properties",
      "sudo chown -R kafka:kafka /opt/kafka",
      # create kafka service
      "cat <<EOF > /$HOME/kafka.service",
      "[Unit]",
      "Description=Apache Kafka server (broker)",
      "Documentation=http://kafka.apache.org/documentation.html",
      "Requires=zookeeper.service",
      "After=zookeeper.service",
      "[Service]",
      "LimitNOFILE=100000",
      "Type=simple",
      "User=kafka",
      "Group=kafka",
      "Environment=JAVA_HOME=/usr/lib/jvm/java-11",
      "Environment=KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/kafka/config/kafka_server_jaas.conf",
      "ExecStart=/bin/sh -c '/opt/kafka/kafka/bin/kafka-server-start.sh /opt/kafka/kafka/config/server.properties > /opt/kafka/kafka/logs/kafka.log 2>&1'",
      "ExecStop=/opt/kafka/kafka/bin/kafka-server-stop.sh",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo cp /$HOME/kafka.service /etc/systemd/system/kafka.service",
      # start kafka
      "sudo systemctl daemon-reload",
      "sudo systemctl enable kafka",
      "sudo service kafka start",
    ]
    connection {
      type = "ssh"
      host = var.host
      user = var.username
      password = var.password
      #private_key = file("private_key.pem")
    }
  }
}