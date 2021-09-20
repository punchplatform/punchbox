# Logstash channel

THe principle here is to have logstashtht receives some input on port
5800, then writes that data into a kafka topic. 

Next a punchline (punchline.yaml) read that topic, parse and print the 
data. 

To try it start the channel:

```sh
channelctl start --channel logstash
```
Then some some message:

```sh
echo -e "some message" | nc localhost 9800
```

See the result it the shiva logs. You should find the logs
in $PUNCHPLATFORM_SHIVA_INSTALL_DIR/logs.


