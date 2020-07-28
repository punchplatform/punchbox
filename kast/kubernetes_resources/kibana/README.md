# Kibana Deployment

##  Prerequisites
- a cluster up and running with kubernetes installed
-  kubectl configured to deploy resources in your cluster
- a Elasticsearch cluster deployed

 
## Configuration 
You can configure your **Kibana** nodes with global environment variables ([Kibana configuration](https://www.elastic.co/guide/en/kibana/current/settings.html))
To configure you just need to add yours environment variables in this field : ``Deployment.spec.template.spec.containers.env``
####  Importants Settings
The environment variable **ELASTICSEARCH_HOSTS** corresponding to the FQDN of your kubernetes services in charge of route resquest to kubernetes pod of your elasticsearch cluster.
The FQDN is define by ***service_name.namespace*** .

If you have deploy Elasticsearch with "all roles mode", the host url is http://es-svc.elk:9200 .
If you have deploy Elasticsearch with "dedicated roles mode", the host url is http://es-routing.elk:9200 .

You can customize your deployment by modify (CPU, RAM, number of nodes ...) in the file ``kibana.yaml``

 Kibana is by default configured to run on a Kubernetes cluster on premise. 
If you have a kubernetes cluster in cloud you need to change the field ``Service.spec.type`` with the value ``LoadBalancer``


##  Deployment

```sh
kubectl create -f kubernetes_resources/kibana/kibana.yaml
```
This file will create 2 kubernetes objects :
- a Service in charge to route connections to kibana Pods.
- a Deployment in charge of managing and scaling  a set of Pods

Kibana will be exposed on port 31000 of yours nodes so you need to check your firewall configuration.

When you have check your firewall configuration, you need to know where Kibana pods are deployed.

```sh
kubectl get pod -n elk -o wide
```
After getting node name, you can retrieve node ip by using  the following command :

```sh
kubectl get node -o wide
```
 Now you can access to your **Kibana** with the url : ``{NodeIP}:31000``

## Scaling the Cluster
You can scale Kibana cluster by updating the number of `Deployment.spec.replicas` field. You can perform this with the `kubectl scale` command.
```sh
kubectl scale deploy kiban-svc -n elk --replicas=4
```

