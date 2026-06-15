# global_pinner.rb
require 'json'
require 'net/http'
require 'time'
require 'pathname'
require 'rubygems/requirement'

DAYS_BACK = 5
SECONDS_PER_DAY = 24 * 60 * 60
TARGET_DATE = Time.now.utc - (DAYS_BACK * SECONDS_PER_DAY)
RUBYGEMS_HOST = 'https://rubygems.org'
PINNER_DISABLED = ENV['INSTANA_DISABLE_GLOBAL_PINNER'] == 'true'
GLOBAL_PINNER_PATH = File.expand_path(__FILE__)
GLOBAL_PINNER_DIR = File.dirname(GLOBAL_PINNER_PATH)

module GlobalPinner
  module_function

  def install!
    return if PINNER_DISABLED
    return if @installed

    ensure_rubyopt_uses_absolute_path

    @installed = true

    # If Bundler is already loaded, patch it immediately
    if defined?(Bundler::Dsl)
      Bundler::Dsl.prepend(DslPatch)
    end

    if defined?(Bundler::Injector)
      Bundler::Injector.prepend(InjectorPatch)
    end

    # Set up a hook to patch Bundler when it loads
    setup_bundler_hook unless defined?(Bundler)
  end

  def setup_bundler_hook
    trace = TracePoint.new(:class) do |tp|
      if tp.self.name == 'Bundler'
        # Wait for Bundler::Dsl to be defined
        dsl_trace = TracePoint.new(:class) do |dsl_tp|
          if dsl_tp.self.name == 'Bundler::Dsl'
            Bundler::Dsl.prepend(DslPatch)
            dsl_trace.disable
          end
        end
        dsl_trace.enable

        # Wait for Bundler::Injector to be defined
        injector_trace = TracePoint.new(:class) do |inj_tp|
          if inj_tp.self.name == 'Bundler::Injector'
            Bundler::Injector.prepend(InjectorPatch)
            injector_trace.disable
          end
        end
        injector_trace.enable

        trace.disable
      end
    end
    trace.enable
  end

  def pinned_version_for(name, requirements)
    versions = fetch_versions(name)
    grace_cutoff = Time.now.utc - (DAYS_BACK * SECONDS_PER_DAY)
    current_ruby_version = Gem::Version.new(RUBY_VERSION)

    # Filter and sort versions by created_at descending
    sorted_versions = versions
      .select { |v| v['created_at'] && !v['prerelease'] }
      .map { |v| [v, Time.parse(v['created_at'])] }
      .sort_by { |_, created_at| created_at }
      .reverse

    # Find first safe version with grace period reset logic
    sorted_versions.each_with_index do |(version, created_at), i|
      # Skip if within grace period
      next if created_at > grace_cutoff

      # Check if superseded by newer version within grace period
      grace_end = created_at + (DAYS_BACK * SECONDS_PER_DAY)
      superseded = sorted_versions[0...i].any? do |_, newer_date|
        newer_date < grace_end
      end

      next if superseded

      # Check if version satisfies requirements
      number = version['number']
      next unless requirement_for(requirements).satisfied_by?(Gem::Version.new(number))

      # Check Ruby version compatibility
      ruby_requirement = version['ruby_version']
      if ruby_requirement && !Gem::Requirement.new(ruby_requirement).satisfied_by?(current_ruby_version)
        next
      end

      return number
    end

    nil
  rescue StandardError => e
    warn "[Date Pinner] Failed to pin #{name}: #{e.class}: #{e.message}"
    nil
  end

  def fetch_versions(name)
    uri = URI.parse("#{RUBYGEMS_HOST}/api/v1/versions/#{name}.json")
    response = Net::HTTP.get_response(uri)
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def requirement_for(requirements)
    cleaned = requirements.flatten.compact.reject { |value| value.is_a?(Hash) }
    return Gem::Requirement.default if cleaned.empty?

    Gem::Requirement.new(*cleaned)
  end

  module DslPatch
    def gem(name, *requirements)
      pinned_version = GlobalPinner.pinned_version_for(name, requirements)

      if pinned_version
        puts "   [Date Pinner] #{name} -> #{pinned_version}"
        super(name, pinned_version)
      else
        super(name, *requirements)
      end
    end
  end

  module InjectorPatch
    def gem(name, *requirements)
      pinned_version = GlobalPinner.pinned_version_for(name, requirements)

      if pinned_version
        puts "   [Date Pinner] #{name} -> #{pinned_version}"
        super(name, pinned_version)
      else
        super(name, *requirements)
      end
    end
  end

  def ensure_rubyopt_uses_absolute_path
    rubyopt = ENV['RUBYOPT'] || ''

    relative_flag = '-r./global_pinner'
    absolute_flag = "-r#{GLOBAL_PINNER_PATH}"

    # Remove any existing references to global_pinner (relative or absolute)
    updated_rubyopt = rubyopt.gsub(/#{Regexp.escape(relative_flag)}|#{Regexp.escape(absolute_flag)}/, '').strip

    # Add the absolute path reference
    updated_rubyopt = "#{updated_rubyopt} #{absolute_flag}".strip

    ENV['RUBYOPT'] = updated_rubyopt
  end
end

GlobalPinner.install!
