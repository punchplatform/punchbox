# Punchbox configuration

You could update existing ones or create a new one with your specific configuration.

Check this Punchbox config file as an example : [punchbox_config.json](../configurations/punchbox_config.json)

Update the Json sections :

* `targets` to configure vagrant boxes
* `punch` to configure a Punch deployment

To configure vagrant boxes, read the [Vagran with Punchbox documentation](../punch/vagrant/README.md).

To configure a Punch Deployment, follow :

- `punch`: Optional, list of punch component  
    - `tls`: Optional, default `false`. If `true`, enable TLS for all supported components.
    - `setups_root` : Optional, default `/data/opt`. Path where the punch components binaries will be installed.
    - `data_root` : Optional, default `/data/opt`. Path where the punch components data will be stored.
    - `reporters` : **Mandatory**
        - `kafka_cluster`: **Mandatory**, name of the kafka cluster to target.
    - `operators` : **Mandatory**
        - `kafka_cluster`: **Mandatory**, name of the kafka cluster to target.
    - `zookeeper`:
        - `max_memory`: Optional, default `512m`. Max RAM usage for each zookeeper server.
        - `clusters.<clustername>.servers`: **Mandatory**, list of zookeeper hosts.
    - `kafka`:
        - `clusters.<clustername>.servers`:  **Mandatory**, list of kakfa hosts.
    - `elasticsearch`:
        - `max_memory`: Optional, default `512M`. Max RAM usage for each elasticsearch node.
        - `clusters.<clustername>.servers`: **Mandatory**, list of elasticsearch hosts.
    - `gateway`:
        - `clusters.<clustername>`:
            - `servers`: **Mandatory**, list of gateway hosts.
            - `es_data_cluster`: **Mandatory**, name of the ES data cluster for Gateway.
            - `es_metric_cluster`: **Mandatory**, name of the ES metric cluster for Gateway.              
            - `tenant`: Optional, default `<cluster_name>`. Name of the Gateway's tenant.
    - `kibana`: 
        - `domains.<domain_name>`:
            - `server`: **Mandatory**, kibana host.
            - `es_cluster`: **Mandatory**, name of the ES cluster to target for domain.
            - `plugin_gateway`: Optional, default none. Name of the gateway to target for domain. Enable the punch plugin.
    - `shiva`:
        - `clusters.<clustername>`:
            - `servers`: **Mandatory**, list of shiva hosts.
            - `kafka_cluster`: **Mandatory**, name of the Kafka cluster to store shiva metadata for cluster.
    - `storm`:
        - `max_memory`: Optional, default `128m`. Max RAM usage for each storm node.
        - `clusters.<clustername>`:
            - `master_servers`: **Mandatory**, list of storm master hosts.
            - `zk_cluster`: **Mandatory**, name of the Zookeeper cluster to target.
            - `ui_servers`: Optional, default `master_servers`. List of storm ui hosts.
            - `slave_servers` : Optional, default `master_servers`, List of storm slave hosts.
    -  `spark`:
        - `max_memory`: Optional, default `512M`. Max RAM usage for each spark node.
        - `clusters.<clustername>`:
            - `master_servers`: **Mandatory**, list of spark master hosts.
            - `zk_cluster`: **Mandatory**, name of the Zookeeper cluster to target.
            - `slave_servers` : Optional, default `master_servers`. List of spark slave hosts.
    - `metricbeat`:
        - `es_cluster`: **Mandatory**, name of the ES cluster to target.
    - `minio`:
        - `clusters.<clustername>.servers`: **Mandatory**, list of minio hosts.
    - `clickhouse`:
        - `clusters.<clustername>`:
            - `servers`: **Mandatory**, list of clickhouse hosts.
            - `zk_cluster`: **Mandatory**, name of the Zookeeper cluster to target.