<div align="center">
<img src="http://www.instana.com/wp-content/uploads/2016/11/Instana-Infrastructure-Map-1-1024x551.png"/>
</div>

# Instana

The Instana gem provides Ruby metrics and traces (request, queue & cross-host) for [Instana](https://www.instana.com/).

[![Build Status](https://travis-ci.org/instana/ruby-sensor.svg?branch=master)](https://travis-ci.org/instana/ruby-sensor)
[![Code
Climate](https://codeclimate.com/github/instana/ruby-sensor/badges/gpa.svg)](https://codeclimate.com/github/instana/ruby-sensor)
[![Gem Version](https://badge.fury.io/rb/instana.svg)](https://badge.fury.io/rb/instana)

## Note

This gem supports Ruby versions 2.0 or greater.

Any and all feedback is welcome.  Happy Ruby visibility.

![rails](https://s3.amazonaws.com/instana/rails-logo.jpg?1)
![roda](https://s3.amazonaws.com/instana/roda-logo.png?1)
![cuba](https://s3.amazonaws.com/instana/cuba-logo.png?1)
![sinatra](https://s3.amazonaws.com/instana/sinatra-logo.png?1)
![padrino](https://s3.amazonaws.com/instana/padrino-logo.png?1)
![rack](https://s3.amazonaws.com/instana/rack-logo.png?1)

## Installation

The gem is available on [Rubygems](https://rubygems.org/gems/instana).  To install, add this line to _the end_ of your application's Gemfile:

```ruby
gem 'instana'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install instana

## Usage

The instana gem is a zero configuration tool that will automatically collect key metrics from your Ruby processes.  Just install and go.

## Configuration

Although the gem has no configuration required for out of the box metrics and tracing, components can be configured if needed.

### Agent Reporting

This agent spawns a lightweight background thread to periodically collect and report metrics and traces.  Be default, this uses a standard Ruby thread.  If you wish to have greater control and potentially boot the agent reporting manually in an alternative thread system (such as actor based threads), you can do so with the following:

```Ruby
gem "instana", :require => "instana/setup"
```

...then in the background thread of your choice simply call:

```Ruby
::Instana.agent.start
```

Note that this call is blocking.  It kicks off a loop of timers that periodically collects and reports metrics and trace data.  This should only be called from inside an already initialized background thread:

```Ruby
Thread.new do
  ::Instana.agent.start
end
```

#### Caveat

In the case of forking webservers such as Unicorn or Puma in clustered mode, the agent detects the pid change and re-spawns the background thread.  If you are managing the background thread yourself with the steps above _and_ you are using a forking webserver (or anything else that may fork the original process), you should also do the following.

When a fork is detected, the agent handles the re-initialization and then calls `::Agent.instana.spawn_background_thread`.  This by default uses the standard `Thread.new`.  If you wish to control this, you should override this method by re-defining that method.  For example:

```ruby
# This method can be overridden with the following:
#
module Instana
  class Agent
    def spawn_background_thread
      # start/identify custom thread
      ::Instana.agent.start
    end
  end
end
```

### Components

Individual components can be disabled with a local config.

To disable a single component in the gem, you can disable a single component with the following code:

```Ruby
::Instana.config[:metrics][:gc][:enabled] = false
```
Current components are `:gc`, `:memory` and `:thread`.

### Rack Middleware

This gem will detect and automagically insert the Instana Rack middleware into the middleware stack when a [supported framework](https://instana.atlassian.net/wiki/display/DOCS/Ruby) is present.  We are currently adding support for more frameworks.  If you are using a yet to be instrumented framework, you can insert the Instana Rack middleware with the following:

```Ruby
require "instana/rack"
config.middleware.use ::Instana::Rack
```

...or whatever specific middleware call is appropriate for your framework.

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://instana.atlassian.net/wiki/display/DOCS/Ruby).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

## More

Want Chef change visibility for your deploys?  Checkout [instana-chef](https://github.com/instana/instana-chef).

