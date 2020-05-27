# Kafka Deployment

##  Prerequisites
- a cluster up and running with kubernetes installed
-  kubectl configured to deploy resources in your cluster
 - a zookeeper cluster up and running

## Configuration 
You can configure kafka by simply edit the file ``conf/server.properties``

After editing kafka conf file, you need to create a kubernetes object based on this file by running following command.

```sh
kubectl create configmap kafka-config --from-file=./conf/server.properties
```

## Run deployment
```sh
kubectl create -f kubernetes_resources/kafka/
```

## Testing Kafka Cluster

First you will need to create a topic. You can use `kubectl run` to execute the `kafka-topics.sh` script.

```sh
kubectl run -ti --image=gcr.io/google_containers/kubernetes-kafka:1.0-10.2.1 createtopic --restart=Never --rm -- kafka-topics.sh --create \
--topic test \
--zookeeper zookeeper-client.default.svc.cluster.local:2181 \
--partitions 1 \
--replication-factor 3
```

Now use `kubectl run` to execute the `kafka-console-consumer.sh` script and listen for messages.
```sh
kubectl run -ti --image=gcr.io/google_containers/kubernetes-kafka:1.0-10.2.1 consume --restart=Never --rm -- kafka-console-consumer.sh \
--topic test 
--bootstrap-server kafka-0.kafka-headless.default.svc.cluster.local:9092
```

In another terminal, run the `kafka-console-producer.sh` script.
```sh
kubectl run -ti --image=gcr.io/google_containers/kubernetes-kafka:1.0-10.2.1 produce --restart=Never --rm -- kafka-console-producer.sh \
 --topic test \
 --broker-list kafka-0.kafka-headless.default.svc.cluster.local:9092,kafka-1.kafka-headless.default.svc.cluster.local:9092,kafka-2.kafka-headless.default.svc.cluster.local:9092 done;
```

When you type text into the second terminal. You will see it appear in the first.


## Scaling the Cluster

You can scale the cluster by updating the number of `StatefulSet.spec.replicas` field. You can perform this with the `kubectl scale` command.

```sh
kubectl scale sts kafka --replicas=4
```



