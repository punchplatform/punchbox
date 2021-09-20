# Starting with custom node

This channel uses a custom SMTP input node to simulate an SMTP server, 
receive emails and process them in the chain.

To try this channel you must have the corresponding `punch-smtp-node-6.x.y.jar` artefact 
(not provided in the standalone). It is an example of adding an external jar to
enrich the punch.

## Usage

First create the `mkdir -p $PUNCHPLATFORM_INSTALL_DIR/plugins` folder.

Copy the `punch-smtp-node-6.x.y.jar` to `$PUNCHPLATFORM_INSTALL_DIR/plugins`
and to `$PUNCHPLATFORM_INSTALL_DIR/apache-storm-2.1.0/extlib/`. The former is
needed if you run your punchline in foreground, the later if you submit it to storm.

Start the topology `punchlinectl input.yaml` (foreground mode) or the 
channel `channelctl start --channel smtp` (storm cluster mode)


To test it, from another terminal, send mail with [msmtp](https://doc.ubuntu-fr.org/msmtp) for example, 
and have a look at the logs. 

Logs appear in your terminal or in the output in terminal (foreground mode), $PUNCHPLATFORM_INSTALL_DIR/apache-storm-2.1.0/logs/
folder of the corresponding storm topology. 

With shiva it works similarly. 

