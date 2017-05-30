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

[![rails](https://s3.amazonaws.com/instana/rails-logo.jpg?1)](http://rubyonrails.org/)
[![roda](https://s3.amazonaws.com/instana/roda-logo.png?1)](http://roda.jeremyevans.net/)
[![cuba](https://s3.amazonaws.com/instana/cuba-logo.png?1)](http://cuba.is/)
[![mina logo 100px](https://cloud.githubusercontent.com/assets/395132/23832558/fcd5bdb2-0736-11e7-9809-3016e89698e2.png)](https://github.com/instana/mina-instana)
[![sinatra](https://s3.amazonaws.com/instana/sinatra-logo.png?1)](http://www.sinatrarb.com/)
[![padrino](https://s3.amazonaws.com/instana/padrino-logo.png?1)](http://padrinorb.com/)
[![rack](https://s3.amazonaws.com/instana/rack-logo.png?1)](https://rack.github.io/)

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

Although the gem has no configuration required for out of the box metrics and tracing, components can be configured if needed.  See [Configuration.md](https://github.com/instana/ruby-sensor/blob/master/Configuration.md).

## Tracing

This Ruby gem provides a simple API for tracing and also supports [OpenTracing](http://opentracing.io/).  See [Tracing.md](https://github.com/instana/ruby-sensor/blob/master/Tracing.md) for details.

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://instana.atlassian.net/wiki/display/DOCS/Ruby).

## Want End User Monitoring?

Instana provides deep end user monitoring that links server side traces with browser events.  

For Ruby templates and views, get your EUM API key from your Instana dashboard and you can call `::Instana::Helpers.eum_snippet('example_api_key_string')` from within your layout file.  This will output
a small javascript snippet of code to instrument browser events.  It's based on [Weasel](https://github.com/instana/weasel).  Check it out.

As an example for Haml, you could do the following:

```ruby
%html{ :lang => "en", :xmlns => "http://www.w3.org/1999/xhtml" }
  %head
    - if user_signed_in?
      = raw ::Instana::Helpers.eum_snippet('example_api_key_string', :username => current_user.username)
    - else
      = raw ::Instana::Helpers.eum_snippet('example_api_key_string')
  %body
```
Make sure to use the `raw` helper so the javascript isn't interpolated with escape strings.

The optional second argument to `::Instana::Helpers.eum_snippet` is a hash of metadata key/values that will be reported along
with the browser instrumentation.

![Instana EUM example with metadata](https://s3.amazonaws.com/instana/Instana+Gameface+EUM+with+metadata+2016-12-22+at+15.32.01.png)

See also the [End User Monitoring](https://instana.atlassian.net/wiki/display/DOCS/Web+End-User+Monitoring) in the Instana documentation portal.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

## More

Want to instrument other languages?  See our [Nodejs instrumentation](https://github.com/instana/nodejs-sensor), [Go instrumentation](https://github.com/instana/golang-sensor) or [many other supported technologies](https://www.instana.com/supported-technologies/).

