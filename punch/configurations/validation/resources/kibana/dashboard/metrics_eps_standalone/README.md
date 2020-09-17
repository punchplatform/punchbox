## Dashboard Eps/RTT Standalone

> Warning : This Dashboard can be use only in standalone with a punch version greater or equal to 6.x

### Informations about this dashboard

- **Goal** : Print EPS (Event Per Second) per Spout, Tuple processing per Bolt and RTT (Round Time Travel)

- **Platform type** : **ONLY STANDALONE**

- **Tenant** : mytenant

- **Punch version** : 6.1 =<

- **Based on index pattern** : mytenant-metrics-*

Graphics of this dashboard are built from the index pattern mytenant-metrics-* this index pattern will be created automatically when you import Kibana dashboard.

To import dashboard you need to run following command : 

```sh
punchplatform-setup-kibana.sh --import
```

Find bellow a quick explication of metrics printed in this Dashboard :
 
EPS is a metric computed in milliseconds that corresponding to the number of tuple which output from a Spout.

RTT is a metric computed in milliseconds, it means the time for a tuple to "travel" in Spout or Bolt.

The tuple processing metric corresponding to the time that a tuple have spent in a Bolt.


> In this dashboard we print global metric Max and Average. For Peak (Eps MAX) is the max of max EPS, it is  mean that if you have severals topology it will print the max of all topology not the **SUM**
  
| Metric |Description  |Component Storm | Time aggregation | 
|--|--|--|--|
| EPS MAX/MEAN |  Number max (Peak) / Average  of tuple which output from a Spout | Spout | minute |
| Fail rate |  The rate of tuple that have failed| Spout, Bolt  | minute |
| Tuple processing MAX/MEAN|  Max/Average time passed in a Bolt|Bolt  | minute |
| RTT MAX/MEAN|  Max/Average time for a tuple to travel in the pipeline|Spout, Bolt  | minute |



