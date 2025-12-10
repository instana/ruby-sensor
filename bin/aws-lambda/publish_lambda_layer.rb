#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2025

require 'json'
require 'fileutils'
require 'time'
require 'aws-sdk-lambda'

CHINA_REGIONS = File.readlines(File.join(File.dirname(__FILE__), 'aws-regions/cn-regions.txt')).map(&:chomp)
OTHER_REGIONS = File.readlines(File.join(File.dirname(__FILE__), 'aws-regions/other_regions.txt')).map(&:chomp)
# Check AWS profiles
["china", "non-china"].each do |profile|
  # Test if we can initialize a client with this profile
  Aws::Lambda::Client.new(profile: profile)
rescue => e
  abort "Please ensure that your aws configuration includes a profile called '#{profile}' " \
        "and has the 'access_key' and 'secret_key' configured for the respective regions: #{e.message}"
end

# Either -dev or -prod must be specified (and nothing else)
if ARGV.length != 1 || !["-dev", "-prod"].include?(ARGV[0])
  abort "Please specify -dev or -prod to indicate which type of layer to build."
end

dev_mode = ARGV[0] == "-dev"

# Determine where this script is running from
this_file_path = File.dirname(File.expand_path(__FILE__))

# Change directory to the base of the Ruby sensor repository
Dir.chdir(this_file_path.to_s)

zip_filename = "layer"

if dev_mode
  target_regions = ["us-east-1"]
  layer_name_prefix = "instana-ruby-dev"
else
  target_regions = CHINA_REGIONS + OTHER_REGIONS
  layer_name_prefix = "instana-ruby"
end

# AWS Lambda supported ruby versions
ruby_supported_runtimes = ["ruby3.2", "ruby3.3", "ruby3.4"]
# Publish each Ruby version as a separate layer
layer_name = layer_name_prefix.to_s
regional_publish = {}
target_regions.each do |region| # rubocop:disable Metrics/BlockLength
  puts "===> Uploading layer for Ruby to AWS #{region}"
  profile = CHINA_REGIONS.include?(region) ? "china" : "non-china"

  # Initialize AWS Lambda client for this region and profile
  lambda_client = Aws::Lambda::Client.new(
    region: region,
    profile: profile
  )

  # Read the zip file content
  zip_file_path = "#{Dir.pwd}/#{zip_filename}.zip"
  zip_content = File.read(zip_file_path, mode: 'rb')

  begin
    # Publish the layer version
    response = lambda_client.publish_layer_version({
                                                     layer_name: layer_name,
                                                     description: "Provides Instana tracing and monitoring of AWS Lambda functions built with Ruby",
                                                     content: {
                                                       zip_file: zip_content
                                                     },
                                                     compatible_runtimes: ruby_supported_runtimes,
                                                     license_info: "MIT"
                                                   })

    version_number = response.version
    puts "===> Uploaded version is #{version_number}"

    unless dev_mode
      puts "===> Making layer public..."
      lambda_client.add_layer_version_permission({
                                                   layer_name: layer_name,
                                                   version_number: version_number,
                                                   statement_id: "public-permission-all-accounts",
                                                   principal: "*",
                                                   action: "lambda:GetLayerVersion"
                                                 })
    end

    regional_publish[region] = response.layer_version_arn
  rescue Aws::Lambda::Errors::ServiceError => e
    puts "Failed to publish layer to #{region}: #{e.message}"
    next
  end
end

puts "===> Published list:"
regional_publish.each do |region, arn|
  puts "#{region}\t#{arn}"
end
