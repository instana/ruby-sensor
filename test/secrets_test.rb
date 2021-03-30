# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class SecretsTest < Minitest::Test
  def setup
    @subject = Instana::Secrets.new(logger: Logger.new('/dev/null'))
  end

  def test_equals_ignore_case
    sample_config = {
      "matcher"=>"equals-ignore-case",
      "list"=>["key"]
    }

    url = url_for(%w(key Str kEy KEY))
    assert_redacted @subject.remove_from_query(url, sample_config), %w(key kEy KEY)
  end

  def test_equals
    sample_config = {
      "matcher"=>"equals",
      "list"=>["key", "kEy"]
    }

    url = url_for(%w(key Str kEy KEY))
    assert_redacted @subject.remove_from_query(url, sample_config), %w(key kEy)
  end

  def test_contains_ignore_case
    sample_config = {
      "matcher"=>"contains-ignore-case",
      "list"=>["stan"]
    }

    url = url_for(%w(instantiate conTESTant sample))
    assert_redacted @subject.remove_from_query(url, sample_config), %w(instantiate conTESTant)
  end

  def test_contains
    sample_config = {
      "matcher"=>"contains",
      "list"=>["stan"]
    }

    url = url_for(%w(instantiate conTESTant sample))
    assert_redacted @subject.remove_from_query(url, sample_config), %w(instantiate)
  end

  def test_regexp
    sample_config = {
      "matcher"=>"regex",
      "list"=>["l{2}"]
    }

    url = url_for(%w(ball foot move))
    assert_redacted @subject.remove_from_query(url, sample_config), %w(ball)
  end

  def test_invalid
    sample_config = {
      "matcher"=>"test_invalid",
      "list"=>["key"]
    }

    url = url_for(%w(key Str kEy KEY))
    assert_redacted @subject.remove_from_query(url, sample_config), []
  end

  def test_without_scheme
    sample_config = {
      "matcher"=>"contains",
      "list"=>["stan"]
    }

    url = 'example.com?instantiate=true'
    assert_redacted @subject.remove_from_query(url, sample_config), %w(instantiate)
  end

  private

  def url_for(keys)
    url = URI('http://example.com')
    url.query = URI.encode_www_form(keys.map { |k| [k, rand(1..100)]})
    url.to_s
  end

  def assert_redacted(str, keys)
    url = URI(str)
    params = CGI.parse(url.query)

    assert_equal keys, params.select { |_, v| v == %w(<redacted>) }.keys, 'to be redacted'
  end
end
