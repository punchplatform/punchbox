# Channel Monitoring

This channel is in charge of monitoring the other channels
of this tenant. Such channels are used on production punch
to provide additional and valuable insight about the other channel
behavior.

It is composed of a shiva application that reads events and logs 
from the central reporter kafka topic, performs some parsing 
then forward them to the appropriates elasticsearch indices.
      
The channel monitoring app is a built-in punch application.
That means the required packaged are pre-installed on shiva nodes.

No resources are required. The topic used for reporting pre-exists.
It is specified in the channels_monitoring.json file. 

