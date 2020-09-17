# Monitoring dashboards

## Channels monitoring

    * "shiva_tasks_monitoring.ndjson"

        This define a dashboard called "[PTF / Channels Monitoring] Shiva tasks" that displays :

            - Last shiva cluster known event for each application
            - Logs collected from shiva applications

        This is useful to analyse if a shiva task has been started, what errors it has encountered...

        This is a reference configuration item developed for DAVE 6.1 release - 31/08/2020 by CVF


    * "channels_application_states.ndjson"

                This define a dashboard called "[ PTF / Channels Monitoring ] Channels applications states" that displays :

                - Last operator command for each channel application (start or stop)

                - Small uptimes of tasks and number of restarts in selected time scope
