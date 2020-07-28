# Role to configure a Punchplatform deployer

## Required variables

pp_deployer_version: punchplatform version
pp_local_deployers_dir: local directory in which punchplatform deployer in stored (e.g. /data/punchplatform-dists)
pp_remote_deployment_user: remote user 
pp_remote_setups_dir: directory in which will be stored all data (e.g. /data)

## Optional variables

Setting these variables will activate punchplatform configuration management while configuring deployer 

pp_local_conf_dir: local directory in which punchplatform config is stored
pp_conf_name: punchplatform conf folder name