# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class UtilTest < Minitest::Test
  include Instana::TestHelpers

  def setup
    @orig_classify_all = ::Instana.config[:http_exit_classify_all_4xx_as_errors]
    @orig_classify_codes = ::Instana.config[:http_exit_classify_as_errors]
  end

  def teardown
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = @orig_classify_all
    ::Instana.config[:http_exit_classify_as_errors] = @orig_classify_codes
  end

  def test_get_rb_source_error
    assert_equal({ error: "Only Ruby source files are allowed. (*.rb)" }, Instana::Util.get_rb_source('invalid.txt'))
  end

  # -------------------------------------------------------------------------
  # Default behaviour — 4xx never an error, 5xx always an error
  # -------------------------------------------------------------------------

  def test_5xx_is_always_an_error_in_default_mode
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors] = []

    assert ::Instana::Util.should_mark_http_exit_as_error?(500)
    assert ::Instana::Util.should_mark_http_exit_as_error?(503)
  end

  def test_4xx_is_not_an_error_in_default_mode
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors] = []

    refute ::Instana::Util.should_mark_http_exit_as_error?(400)
    refute ::Instana::Util.should_mark_http_exit_as_error?(401)
    refute ::Instana::Util.should_mark_http_exit_as_error?(404)
    refute ::Instana::Util.should_mark_http_exit_as_error?(499)
  end

  def test_2xx_and_3xx_are_never_errors
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = true
    ::Instana.config[:http_exit_classify_as_errors] = []

    refute ::Instana::Util.should_mark_http_exit_as_error?(200)
    refute ::Instana::Util.should_mark_http_exit_as_error?(301)
  end

  # -------------------------------------------------------------------------
  # classify_all_4xx mode
  # -------------------------------------------------------------------------

  def test_all_4xx_are_errors_when_classify_all_is_true
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = true
    ::Instana.config[:http_exit_classify_as_errors] = []

    assert ::Instana::Util.should_mark_http_exit_as_error?(400)
    assert ::Instana::Util.should_mark_http_exit_as_error?(401)
    assert ::Instana::Util.should_mark_http_exit_as_error?(404)
    assert ::Instana::Util.should_mark_http_exit_as_error?(429)
    assert ::Instana::Util.should_mark_http_exit_as_error?(499)
  end

  # -------------------------------------------------------------------------
  # classify specific codes mode
  # -------------------------------------------------------------------------

  def test_only_listed_codes_are_errors
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors] = [401, 404]

    assert ::Instana::Util.should_mark_http_exit_as_error?(401)
    assert ::Instana::Util.should_mark_http_exit_as_error?(404)
    refute ::Instana::Util.should_mark_http_exit_as_error?(429)
    refute ::Instana::Util.should_mark_http_exit_as_error?(400)
  end

  def test_classify_as_errors_takes_priority_over_classify_all
    # When both are set, classify_as_errors list wins
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = true
    ::Instana.config[:http_exit_classify_as_errors] = [401]

    assert ::Instana::Util.should_mark_http_exit_as_error?(401)
    # 404 would match classify_all but the list takes priority → not listed → not an error
    refute ::Instana::Util.should_mark_http_exit_as_error?(404)
  end

  # -------------------------------------------------------------------------
  # http_reason_phrase
  # -------------------------------------------------------------------------

  def test_http_reason_phrase_known_codes
    assert_equal 'Unauthorized',       ::Instana::Util.http_reason_phrase(401)
    assert_equal 'Forbidden',          ::Instana::Util.http_reason_phrase(403)
    assert_equal 'Not Found',          ::Instana::Util.http_reason_phrase(404)
    assert_equal 'Method Not Allowed', ::Instana::Util.http_reason_phrase(405)
    assert_equal 'Internal Server Error', ::Instana::Util.http_reason_phrase(500)
  end

  def test_http_reason_phrase_unknown_code_returns_nil
    assert_nil ::Instana::Util.http_reason_phrase(499)
  end
end
