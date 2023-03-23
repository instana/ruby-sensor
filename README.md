<div align="center">
<img src="https://disznc.s3.amazonaws.com/Ruby-Dashboard-2020-02-10-at-2.31.36-PM.png"/>
</div>

# Instana

The `instana` gem provides Ruby metrics and traces (request, queue & cross-host) for [Instana](https://www.instana.com/).

This gem supports Ruby versions 2.7 or greater.

Any and all feedback is welcome.  Happy Ruby visibility.

[![Gem Version](https://badge.fury.io/rb/instana.svg)](https://badge.fury.io/rb/instana)
[![CircleCI](https://circleci.com/gh/instana/ruby-sensor.svg?style=svg)](https://circleci.com/gh/instana/ruby-sensor)
[![OpenTracing Badge](https://img.shields.io/badge/OpenTracing-enabled-blue.svg)](http://opentracing.io)

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

The `instana` gem is a zero configuration tool that will automatically collect key metrics and distributed traces from your Ruby processes.  Just install and go.

### Supported Frameworks

* [Cuba](https://cuba.is/)
* [gRPC](https://grpc.io/)
* [Padrino](https://padrinorb.com/)
* [Roda](https://roda.jeremyevans.net/)
* [Ruby on Rails](https://rubyonrails.org/)
* [Rack](https://rack.github.io/)
* [Sinatra](https://sinatrarb.com/)

## Configuration

Although the gem has no configuration required for out of the box metrics and tracing, components can be configured if needed.  See our [Configuration](https://docs.instana.io/ecosystem/ruby/configuration/) page.

## Tracing

This Ruby gem provides a simple API for tracing and also supports [OpenTracing](http://opentracing.io/).  See the [Ruby Tracing SDK](https://docs.instana.io/ecosystem/ruby/tracing-sdk/) and [OpenTracing](https://docs.instana.io/ecosystem/ruby/opentracing/) pages for details.

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://docs.instana.io/ecosystem/ruby/).

## Want End User Monitoring (EUM)?

Instana provides deep end user monitoring that links server side traces with browser events to give you a complete view from server to browser.

See the [End User Monitoring](/products/website_monitoring/#configuration) page for more information.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bundle exec rake console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/instana/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

## More

Want to instrument other languages?  See our [Node.js](https://github.com/instana/nodejs), [Go](https://github.com/instana/golang-sensor), [Python](https://github.com/instana/python-sensor) repositories or [many other supported technologies](https://www.instana.com/supported-technologies/).
