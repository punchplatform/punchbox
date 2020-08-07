# Information

This example illustrate how to perform an aggregation.
By default, the elasticsearch query being used is based on generating an UTC timezone...

In case you wish to control the time zone being used for your elasticsearch query, please use the below plan.hjson instead:

```ruby
{
  configurations:{
    input_index: mytenant-events-*
    output_index: mytenant-aggregations
    nodes: [ "localhost" ]
  }
  cron: "*/1 * * * *"
  dates: {
    day: {
      duration: -PT1m
      format: yyyy.MM.dd
    }
    from: {
      duration: -PT1m
      format: yyyy-MM-dd'T'hh:mm:ss  
    }
    to: {
      format: yyyy-MM-dd'T'hh:mm:ss
    }
    timezone: {
      format: +00:00
    }
  }
}
```

Futhermore, replace the query field in our `job.template`
with this one:

```ruby
query: {
  aggregations: {
    by_channel: {
      aggregations: {
        max_size: {
          max: {
            field: size
          }
        }
        total_size: {
          sum: {
            field: size
          }
        }
      }
      terms: {
        field: vendor
      }
    }
  }
  query: {
    bool: {
      must: [
        {
          range: {
            @timestamp: {
              gte: "{{ from }}"
              lt: "{{ to }}"
              time_zone: "{{ timezone }}"
            }
          }
        }
      ]
    }
  }
  size: 0
}
```	
