# For development/testing, you can run this instrumentation
# interactively in a Docker container:
# docker build -t instana/ruby-sensor-console:0.1
# docker run -it instana/ruby-sensor-console:0.1
#
FROM ruby:2.3.1
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs openssh-client git vim zip curl uni2ascii bsdmainutils
RUN mkdir /ruby-sensor
WORKDIR /ruby-sensor
COPY Gemfile Gemfile.lock instana.gemspec ./
COPY . ./
RUN gem install bundler && bundle install --jobs 20 --retry 5
CMD bundle exec rake console
