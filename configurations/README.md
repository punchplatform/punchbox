# User config 

From a user point of view only files under this folder can be modified (the file provided with --config option)
You can update existing ones or create a new one with your specific configuration.

This file is composed as follow : 

  - `targets`: details about targets machines
      - `info`: list of targets 
          - `server_name`: string to identify a box
              - `disksize`: size of disk box
              - `memory`: memory size of box
              - `cpu`: number of cpu for box
      - `meta`: common details for all boxes
          - `os`: os for all boxes

  - `punch`: list of punch component. Do not put any if all you want is an empty cluster.
      - `installation_directory` : path where the punch components binaries will be installed
      - `data_storage_directory` : path where the punch components data will be stored
      - `elasticsearch`:
          - `servers`: list of elasticsearch hosts
          - `cluster_production_transport_address`: elasticsearch transport address
          - `memory`: maximum size of each elasticsearch nodes Jvm memory
          - `security` : if true, enable Opendistro Security plugin and Opendistro alerting plugin. It will generate 
          configuration for SSL, authentication and security management. The security resource folder will be used to
          deploy default certificates
      - `kibana`: 
          - `servers`: list of kibana hosts
          - `security` : if true, enable Opendistro Security plugin and Opendistro alerting plugin. It will generate 
          configuration for SSL, authentication and security management. The security resource folder will be used to
          deploy default certificates
      - `zookeeper`: 
          - `servers`: list of zookeeper hosts
          - `childopts`: JVM options for zookeeper
      - `gateway`: 
          - `servers`: list of gateway hosts 
          - `inet_address`: inet address for gateway (will be remove soon)
          - `security` : if true, enable ssl connections to, and from, gateway's rest api. It will generate 
          configuration for SSL. The security resource will be used to deploy a  default keystore.
      - `storm`: 
          - `master`: 
              - `servers`: list of storm master hosts
              - `cluster_production_address`: cluster address for storm master
          - `ui`:
              - `servers`: list of storm ui hosts
              - `cluster_admin_url`: cluster address for storm ui
          - `slaves` : list of storm slave hosts
          - `workers_childopts`: storm worker jvm options
          - `supervisor_memory_mb`: size of RAM for supervisor
      - `kafka`:
          - `brokers`: list of kafka brokers
          - `jvm_xmx`: max JVM size for each kafka broker 
      - `shiva`: 
          - `servers`: list of shiva hosts
      -  `spark`:
          - `masters`: list of spark master hosts
          - `slaves`: list of spark slave hosts
          - `slaves_memory`: allocation of memory for each slaves
      - `pyspark`:
          - `servers`: list of pyspark hosts
      - `minio`:
          - `servers`: list of minio hosts
      - `clickhouse`:
          - `servers`: list of clickhouse hosts
      - `operator`: 
          - `servers`: list of operator hosts
          - `username`: operator username

      
**Note** : All parameters under `targets` key are mandatory. For those under `punch`, they are optional

**Note** : do **never** add or change things in the platform_template or vagrant without a first review with the core punch team leaders