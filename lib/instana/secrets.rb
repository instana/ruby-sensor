require 'uri'
require 'cgi'

module Instana
  class Secrets    
    def remove_from_query(str, secret_values = Instana.agent.secret_values)
      return str unless secret_values
      
      url = URI(str)
      params = CGI.parse(url.query)
      
      redacted = params.map do |k, v|
        needs_redaction = secret_values['list']
          .any? { |t| matcher(secret_values['matcher']).(t,k) }
        [k, needs_redaction ? '<redacted>' : v]
      end
      
      url.query = URI.encode_www_form(redacted)
      CGI.unescape(url.to_s)
    end
    
    private
    
    def matcher(name)
      case name
      when 'equals-ignore-case'
        ->(expected, actual) { expected.casecmp(actual) == 0 }
      when 'equals'
        ->(expected, actual) { (expected <=> actual) == 0 }
      when 'contains-ignore-case'
        ->(expected, actual) { actual.downcase.include?(expected) }
      when 'contains'
        ->(expected, actual) { actual.include?(expected) }
      when 'regex'
        ->(expected, actual) { !Regexp.new(expected).match(actual).nil? }
      else
        ::Instana.logger.warn("Matcher #{name} is not supported.")
        lambda { false }
      end
    end
  end
end
