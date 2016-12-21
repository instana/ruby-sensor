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

See [Tracing.md](https://github.com/instana/ruby-sensor/blob/master/Tracing.md)

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://instana.atlassian.net/wiki/display/DOCS/Ruby).

## Want End User Monitoring?

Instana provides deep end user monitoring that links server side traces with browser events.  See [End User Monitoring](https://instana.atlassian.net/wiki/display/DOCS/Web+End-User+Monitoring) in the Instana documentation portal.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

## More

Want Chef change visibility for your deploys?  Checkout [instana-chef](https://github.com/instana/instana-chef).

