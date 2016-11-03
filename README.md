<div align="center">
<img src="https://www.instana.com/wp-content/uploads/2016/04/stan@2x.png">
</div>

# Instana

The Instana gem provides Ruby metrics for [Instana](https://www.instana.com/).

## Note

This gem is currently in beta and supports Ruby versions 2.0 or greater.

Any and all feedback is welcome.  Happy Ruby visibility.

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

Although the gem has no configuration required for metrics, individual components can be disabled with a local config.

To disable a single component in the gem, you can disable a single component with the following code:

```Ruby
::Instana.config[:metrics][:gc][:enabled] = false
```
Current components are `:gc`, `:memory` and `:thread`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

