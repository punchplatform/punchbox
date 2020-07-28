# LOGSTASH Deployment

##  Prerequisites
- a cluster up and running with kubernetes installed
-  kubectl configured to deploy resources in your cluster
- a Elasticsearch cluster deployed

 
## Configuration 
You can configure your **Logstash** node by modify the file ``conf/logstash.yml``


####  Importants Settings
The environment variable **xpack.monitoring.elasticsearch.hosts** corresponding to the FQDN of your kubernetes services in charge of route resquest to kubernetes pod of your elasticsearch cluster.
The FQDN is define by ***service_name.namespace***.

If you have deploy Elasticsearch with "all roles mode", the host url is http://es-svc.elk:9200  (*default value*)
If you have deploy Elasticsearch with "dedicated roles mode", the host url is http://es-routing.elk:9200 .

You can customize your deployment by modify (CPU, RAM, number of nodes ...) in the file ``logstash_deploy.yaml``

 Logstash service is by default configured to run on a Kubernetes cluster on premise. 
If you have a kubernetes cluster in cloud you need to change the field ``Service.spec.type`` with the value ``LoadBalancer``


##  Deployment
First you need to create two kubernetes ConfigMap based on configuration files of the folder ``config``. 

The aim of the first ConfigMap is to store the configuration of **Logstash** server.
```sh
kubectl create configmap -n elk logstash-config --from-file ./conf/logstash.yml
```
The aim of the seconde ConfigMap is to store a configuration of a parser.
```sh
kubectl create configmap -n elk log-parse --from-file ./conf/logstash.conf
```
After creating ConfigMaps you can deploy your cluster **Logstash**

```sh
kubectl create -f kubernetes_resources/logstash/logstash_deploy.yaml
```
This file will create 2 kubernetes objects :
- a Service in charge to route logs to logstash Pods, this service is type of NodePort or LoadBalancer(Cloud) to permit receive logs from external services.
- a Deployment in charge of managing and scaling  a set of Pods

Logstash will be exposed on port 30113 and FileBeat connector will be exposed on port 30114 of yours Kubernetes nodes so you need to check your firewall configuration.

When you have check your firewall configuration, you need to know where Logstash pods are deployed.

```sh
kubectl get pod -n elk -o wide
```
After getting node name, you can retrieve node ip by using  the following command :

```sh
kubectl get node -o wide
```
 Now you can send logs to **Logstash** with the url  ``{NodeIP}:30113``
 If you use  Filebeat you send logs to **Logstash** with the url ``{NodeIP}:30114``


##  Test with FileBeat


You can test your ELK stack with FileBeat, follow these steps to send logs to **Logstash** and visualize received logs in **Kibana**.

In this example we use the docker image of filebeat 7.6.2.

The  ``test``folder contains two files :
- ``logstash-tutorial.log`` : a log sample
- ``filebeat.yml``: filebeat configuration to send logs to logstash

You need to modify the field ``hosts``in  ``filebeat.yml``with our host information.

After that, run below command to create a docker container that mount this two files and send logs to specified url.

In a Terminal run this command :
```sh
docker run \
	-v {your_absolute_path}/logstash-tutorial.log:/usr/share/filebeat/logstash-tutorial.log \

	-v {your_absolute_path}/filebeat.yml:/usr/share/filebeat/filebeat.yml \

	--name filebeat docker.elastic.co/beats/filebeat:7.7.0
```
Normally you will see logs sending, to check if logstash have correctly receive logs, you  can use the command ``kubeclt logs``, first you need to retrieve the id of **Logstash Pods**  with this command : 

```sh
kubectl get pod -n elk
```
Then you can print logs of logstash pod (*replace by our logstash pod id*).
```sh
kubectl logs -f pod/logstash-f99fc7c86-c4jpv -n elk
```
Done ! you have a ELK stack working and scalable. Now create a index pattern in Kibana and visualize your logs.

## Scaling the Cluster
You can scale **Logstash** cluster by updating the number of `Deployment.spec.replicas` field. You can perform this with the `kubectl scale` command.
```sh
kubectl scale deploy logstash-svc -n elk --replicas=2
```

