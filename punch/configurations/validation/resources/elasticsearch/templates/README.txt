The PunchPlatform can be configured to automatically apply the index mapping templates defined
here. I.e. the platform admin service automatically puts these to Elasticsearch, using a periodic
scheduling configured by your administrator. 

Checkout the $PUNCHPLATFORM_CONF_DIR/tenants/platform/admin service. It is explained there.
Should you require to refresh yourself one or all of the mapping here simply use something like :

     $ curl -XPUT localhost:9200/_template/mapping_metrics -H "Content-Type: application/json" -d @mapping_metrics.json

