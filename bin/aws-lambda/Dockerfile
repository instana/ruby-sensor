FROM public.ecr.aws/lambda/ruby:3.4 as ruby_dependencies_34

# Install system dependencies for native extensions
RUN dnf update -y && \
    dnf install -y gcc gcc-c++ make

# Configure bundler and install gems
RUN echo "source 'https://rubygems.org'; gem 'instana'; gem 'get_process_mem'" > Gemfile && \
    bundle config set --local path vendor/bundle && \
    bundle install

# Create the layer structure
RUN mkdir -p ruby/gems/3.4.0 && \
    cp -r vendor/bundle/ruby/3.4.0*/* ruby/gems/3.4.0/

# Create the layer zip file
# RUN zip -r /layer.zip ruby/

FROM public.ecr.aws/lambda/ruby:3.3 as ruby_dependencies_33

# Install system dependencies for native extensions
RUN dnf update -y && \
    dnf install -y gcc gcc-c++ make

# Configure bundler and install gems
RUN echo "source 'https://rubygems.org'; gem 'instana'; gem 'get_process_mem'" > Gemfile && \
    bundle config set --local path vendor/bundle && \
    bundle install

# Create the layer structure
RUN mkdir -p ruby/gems/3.3.0 && \
    cp -r vendor/bundle/ruby/3.3.0*/* ruby/gems/3.3.0/

# Create the layer zip file
# RUN zip -r /layer.zip ruby/

FROM public.ecr.aws/lambda/ruby:3.2 as ruby_dependencies_32

# Install system dependencies for native extensions
RUN yum update -y && \
    yum install -y gcc gcc-c++ make && \
    yum install -y zip

# Configure bundler and install gems
RUN echo "source 'https://rubygems.org'; gem 'instana'; gem 'get_process_mem'" > Gemfile && \
    bundle config set --local path vendor/bundle && \
    bundle install

# Create the layer structure
RUN mkdir -p ruby/gems/3.2.0 && \
    cp -r vendor/bundle/ruby/3.2.0*/* ruby/gems/3.2.0/

RUN pwd
RUN ls -altr
# Create the layer zip file
# RUN zip -r /layer.zip ruby/


FROM  public.ecr.aws/docker/library/alpine:3.22 as final

RUN apk add --no-cache zip unzip

COPY --from=ruby_dependencies_34 /var/task/ruby/ ruby/
COPY --from=ruby_dependencies_33 /var/task/ruby/ ruby/
COPY --from=ruby_dependencies_32 /var/task/ruby/ ruby/

RUN zip -r /layer.zip ruby/
