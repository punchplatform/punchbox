# Starting with custom node

This channel uses a custom SMTP input node to simulate an SMTP server, 
receive emails and process them in the chain.

You must have the `punch-smtp-node-6.2.0-SNAPSHOT.jar` artefact (not provided in the standalone) to operate the channel.


## Usage

- 1/ Create missing directory `mkdir -p $PUNCHPLATFORM_INSTALL_DIR/plugins`

- 2/ Copy the `punch-smtp-node-6.2.0-SNAPSHOT.jar` to `$PUNCHPLATFORM_INSTALL_DIR/plugins` (foreground mode)
and `$PUNCHPLATFORM_INSTALL_DIR/apache-storm-2.1.0/extlib/` (storm cluster mode)

- 3/ Start the topology `punchlinectl input.json` (foreground mode) or the channel `punchctl start --channel smtp` (storm cluster mode)

- 4/ From another terminal, send mail with [msmtp](https://doc.ubuntu-fr.org/msmtp) for example, and show output in terminal (foreground mode),
or  with a third terminal `tail -f $PUNCHPLATFORM_INSTALL_DIR/apache-storm-2.1.0/logs/workers-artifacts/mytenant_smtp_input-<dynamic value here>/6700/worker.log` (storm cluster mode)

