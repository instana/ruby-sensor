#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2025

# Script to make a new AWS Lambda Layer release on Github
# Requires the Github CLI to be installed and configured: https://github.com/cli/cli

require 'json'
require 'open3'

CHINA_REGIONS = File.readlines(File.join(File.dirname(__FILE__), 'aws-regions/cn-regions.txt')).map(&:chomp)
OTHER_REGIONS = File.readlines(File.join(File.dirname(__FILE__), 'aws-regions/other_regions.txt')).map(&:chomp)

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

regions = CHINA_REGIONS + OTHER_REGIONS
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
  puts "The release is available at:"
  puts json_data["html_url"]
else
  puts "Error creating release: #{stderr}"
  exit 1
end
