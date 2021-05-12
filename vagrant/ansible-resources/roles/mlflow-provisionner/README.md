MLFLOW-PROVISIONNER
========================
To launch by the punchbox vagrant provisionner. It Ensures that the mlflow is correctly provisionned with a sample of data.


Requirements
--------------------

* Ubuntu  16.04 LTS
* Ubuntu  18.04 LTS
* CentOS 7
* CentOS 8

Role Variables
-------------------

variables are provided by vagrant by sourcing the punchbox configuration file 

# Dependent variables

# Intrinsic variables
```
punchbox_daemon_user: vagrant
punch:
  minio:
    servers:
      - server2
  mlflow:
    servers:
      server1:
        artifacts_path: "S3://my_bucket"
        port: 5000


```
# Default variables
```
#destination path of all necessaries source files
mlflow_provisionner_src_dir: "/data/mlflow_provisionner_src/" 
#credentials to connect to minio server
mlflow_s3_access_key: "admin"
mlflow_s3_secret_key: "punchplatform"
mlflow_s3_port: 9000


```

Dependencies : 
No known dependencies
