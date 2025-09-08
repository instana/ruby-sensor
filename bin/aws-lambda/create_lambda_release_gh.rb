#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2025

# Script to make a new AWS Lambda Layer release on Github
# Requires the Github CLI to be installed and configured: https://github.com/cli/cli

require 'json'
require 'open3'

if ARGV.length != 1
  raise ArgumentError, 'Please specify the layer version to release. e.g. "1"'
end

if ['-h', '--help'].include?(ARGV[0])
  filename = File.basename(__FILE__)
  puts "Usage: #{filename} <version number>"
  puts "Example: #{filename} 14"
  puts ""
  puts "This will create a AWS Lambda release on Github such as:"
  puts "https://github.com/instana/ruby-sensor/releases/tag/v1"
  exit 0
end

# Check requirements first
["gh"].each do |cmd|
  if `which #{cmd}`.empty?
    puts "Can't find required tool: #{cmd}"
    exit 1
  end
end

regions = %w[
  af-south-1
  ap-east-1
  ap-northeast-1
  ap-northeast-2
  ap-northeast-3
  ap-south-1
  ap-south-2
  ap-southeast-1
  ap-southeast-2
  ap-southeast-3
  ap-southeast-4
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

version = ARGV[0]
semantic_version = "v#{version}"
title = "AWS Lambda Layer #{semantic_version}"

body = "| AWS Region | ARN |\n"
body += "| :-- | :-- |\n"
regions.each do |region|
  body += "| #{region} | arn:aws:lambda:#{region}:410797082306:layer:instana-ruby:#{version} |\n"
end

stdout, stderr, status = Open3.capture3(
  "gh", "api", "repos/:owner/:repo/releases", "--method=POST",
  "-F", "tag_name=#{semantic_version}",
  "-F", "name=#{title}",
  "-F", "body=#{body}"
)

if status.success?
  json_data = JSON.parse(stdout)
  puts "If there weren't any failures, the release is available at:"
  puts json_data["html_url"]
else
  puts "Error creating release: #{stderr}"
  exit 1
end
