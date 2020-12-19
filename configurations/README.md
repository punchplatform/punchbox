# User Configuration Files 

To deploy a punch you must define two yaml files:

* a topology file that lists the nodes and services you want.
  - a zookeeper cluser on three servers
  - a shiva cluster
  - a complete punch with elastc, spark, shiva etc..
* a settings files with the parameter of each property
  - the zookeeper kafka etc.. listening port
  - the /data /var/log /opt and installation folders
  - etc.. 

Here is an example to deploy a three-nodes kafka cluster. Because kafka requires zookeeper, we also deploy a zookeeper cluster.

```yml
---
os: ubuntu/bionic64
servers:
  kafka1:
    disksize: 40GB
    memory: 2000
    cpu: 1
    services:
    - kafka
    - zookeeper
  kafka2:
    disksize: 40GB
    memory: 2000
    cpu: 1
    services:
    - kafka
    - zookeeper
  kafka3:
    disksize: 40GB
    memory: 2000
    cpu: 1
    services:
    - kafka
    - zookeeper
```

Here is an example of a settings file:

```yml
platform:
  platform_id: punchbox-platform-id
  punchplatform_daemons_user: vagrant
  punchplatform_group: vagrant
  remote_data_root_directory: /data
  remote_logs_root_directory: /var/log/punch
  setups_root: /opt

zookeeper:
  cluster_name: punchbox-zookeeper-cluster
  cluster_port: 2181
  punchplatform_root_node: /punchbox
  zookeeper_childopts: -server -Xmx128m -Xms128m

kafka:
  cluster_name: punchbox-kafka-cluster
  brokers_config: punchplatform-local-server.properties
  default_partitions: 2
  default_replication_factor: 1
  kafka_brokers_jvm_xmx: 512M
  partition_retention_bytes: 1073741824
  partition_retention_hours: 24
  zk_cluster: punchbox-zookeeper-cluster
  zk_root: kafka
``` 

