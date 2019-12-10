# For development/testing, you can run this instrumentation
# interactively in a Docker container:
# docker build -t instana/ruby-sensor:1.0
#
# To mount the host ruby-sensor directory in the container:
# docker run -v /host/path/to/ruby-sensor:/ruby-sensor instana/ruby-sensor:1.0 /bin/bash
#
# Once inside the container, you can run `cd /ruby-sensor && bundle install && bundle exec rake console` for a development
# console in the gem.
#
# https://github.com/instana/ruby-sensor#development
#
FROM ruby:2.6
ENV INSTANA_DEBUG=true
RUN gem install bundler
RUN apt update && apt install -y vim
