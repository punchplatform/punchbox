# Role to install a local kubernetes cluster on a single server

Following https://kind.sigs.k8s.io/docs/user/quick-start/


## Required variables

pp_remote_data_dir: directory in which will be stored all data (e.g. /data)
pp_remote_setups_dir: directory to store setups (e.g. /opt or /data/opt)
pp_kube_operator: username of operator for using kube  (e.g. adm-infra)