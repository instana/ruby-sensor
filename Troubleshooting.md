# Troubleshooting

The Instana gem has been designed to be fully automatic in process metric reporting and trace reporting.  But if something
goes wrong, you can use the following steps and tips to potentially diagnose any issues that may exist.

# Supported Components

Make sure that the component that you want to get visibility into has been added to the support matrix.  A list of all
supported components can be found in the [documentation](https://instana.atlassian.net/wiki/display/DOCS/Ruby).

# Logging & Environment Variables

By default, the gem will log informational messages on boot that will indicate if any problems were encountered.  If you
set the `INSTANA_GEM_DEV` environment variable, it will increase the amount of logging output.

![instana console output](https://s3.amazonaws.com/instana/Instana+Ruby+boot+console+logging+output.png)

In the example above, you can see that the host agent isn't available.  Once the host agent is available, the Instana
gem will automatically re-connect without any intervention.

There are even more methods to control logging output.  See the [Configuration](https://github.com/instana/ruby-sensor/blob/master/Configuration.md#logging)
document for details.

# Testing in your Application

To diagnose the Instana gem from your application, often simply opening an application console with verbose logging can be
enough to identify any potential issues:

![rails console](https://s3.amazonaws.com/instana/Instana+Ruby+Rails+console+output.png)

In the example above, you can see the Instana Ruby gem initialize, instrument some components and a success notification: `Host agent available. We're
in business`.
