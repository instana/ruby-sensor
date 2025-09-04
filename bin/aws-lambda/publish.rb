#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2025

require 'json'
require 'fileutils'
require 'time'
require 'aws-sdk-lambda'

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

zip_filename = "layer.zip"

cn_regions = [
  "cn-north-1",
  "cn-northwest-1"
]

if dev_mode
  target_regions = ["us-east-1"]
  layer_name_prefix = "instana-ruby-dev"
else
  target_regions = %w[
    af-south-1
    ap-east-1
    ap-east-2
    ap-northeast-1
    ap-northeast-2
    ap-northeast-3
    ap-south-1
    ap-south-2
    ap-southeast-1
    ap-southeast-2
    ap-southeast-3
    ap-southeast-4
    ap-southeast-5
    ap-southeast-7
    ca-central-1
    ca-west-1
    cn-north-1
    cn-northwest-1
    eu-central-1
    eu-central-2
    eu-north-1
    eu-south-1
    eu-south-2
    eu-west-1
    eu-west-2
    eu-west-3
    il-central-1
    me-central-1
    me-south-1
    sa-east-1
    us-east-1
    us-east-2
    us-west-1
    us-west-2
  ]
  layer_name_prefix = "instana-ruby"
end

published = {}
# AWS Lambda supported ruby versions
ruby_supported_runtimes = ["ruby3.2", "ruby3.3", "ruby3.4"]
# Publish each Ruby version as a separate layer
layer_name = layer_name_prefix.to_s
regional_publish = {}
target_regions.each do |region| # rubocop:disable Metrics/BlockLength
  puts "===> Uploading layer for Ruby #{ruby_version} to AWS #{region}"
  profile = cn_regions.include?(region) ? "china" : "non-china"

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
  published[ruby_version] = regional_publish
end

puts "===> Published list:"
published.each do |ruby_version, regional_publish|
  regional_publish.each do |region, arn|
    puts "#{ruby_version}#{region}\t#{arn}"
  end
end
