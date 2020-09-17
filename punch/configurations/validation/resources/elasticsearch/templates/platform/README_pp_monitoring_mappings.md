# Standard Elasticsearch mapping templates for platform admin/monitoring

These files are `almost mandatory` configuration items for DAVE 6.1 release - checked 31/08/2020 by CVF.

The following mapping files HAVE TO be imported in your admin/monitoring Elasticsearch cluster (not on LTR, that forward their monitoring data to a central site).



|                Filename                |                              Targetted data                              |    Required when ?     |
| :------------------------------------: | :----------------------------------------------------------------------: | :--------------------: |
|    pp_mapping_topology_metrics.json    |               Metrics of punchline and spark applications                |         ALWAYS         |
|      pp_mapping_applications.json      |                                    ?                                     |                        |
|        pp_mapping_archive.json         |                    Metadata tracking archive content                     | When archiving is used |
|        pp_mapping_metadata.json        |               Metadata of Centralized resources repository               |         ALWAYS         |
|     pp_mapping_platform_logs.json      |           Application centralized logs and operator action log           |         ALWAYS         |
|   pp_monitoring_default_refresh.json   |   all monitoring data (overide of ES default refresh interval setting)   |         ALWAYS         |
| pp_mapping_applicative_monitoring.json | Channels monitoring/health history (used by channels monitoring service) |         ALWAYS         |
|        pp_mapping_gateway.json         |                      Event logs of the API Gateway                       |  When gateway is used  |
|  pp_mapping_platform_monitoring.json   | Platform components health history (used by platform monitoring service) |         ALWAYS         |
|    pp_mapping_platform_health.json     |     Platform health synthesis (used by platform monitoring service)      |         ALWAYS         |
|                                        |                                                                          |                        |


When integrating a platform, select the files you need (or all of them if you are unsure), store them in your configuration (e.g. in 'resources/elasticsearch/templates/es_monitoring') and import them using `pp_monitoring_default_refresh.json -d <ES Templates directory> -c <ES cluster id for monitoring cluster>`.

