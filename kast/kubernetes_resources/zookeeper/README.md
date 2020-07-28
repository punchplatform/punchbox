# Zookeeper Deployment


##  Prerequisites
- A cluster up and running with kubernetes
-  kubectl configured to deploy resources in your cluster

## Run deployment


```sh
kubectl create -f kubernetes_resources/zookeeper/
```

## Test Zookeeper

Put some data in zookeeper
```sh
kubectl exec zookeeper-0 zkCli.sh create /hello world
```
Retrieve data
```sh
kubectl exec zookeeper-1 zkCli.sh get /hello
```





