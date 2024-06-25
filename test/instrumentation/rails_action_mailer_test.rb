# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'action_mailer'

class RailsActionMailerTest < Minitest::Test
  class TestMailer < ActionMailer::Base
    def sample_email
      mail_version = Gem::Specification.find_by_name('mail').version
      if mail_version >= Gem::Version.new('2.8.1')
        Mail.new do
          from 'test@example.com'
          to 'test@example.com'
          subject 'Test Email'
          body 'Hello'
          content_type "text/html"
        end
      else
        mail(
          from: 'test@example.com',
          to: 'test@example.com',
          subject: 'Test Email',
          body: 'Hello',
          content_type: "text/html"
        )
      end
    end
  end

  def setup
    TestMailer.delivery_method = :sendmail

    clear_all!
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def test_mailer
    Instana.tracer.start_or_continue_trace(:test) do
      TestMailer.sample_email.deliver_now
    end

    mail_span, = *::Instana.processor.queued_spans

    assert_equal :"mail.actionmailer", mail_span[:n]
    assert_equal 'RailsActionMailerTest::TestMailer', mail_span[:data][:actionmailer][:class]
    assert_equal 'sample_email', mail_span[:data][:actionmailer][:method]
  end

  def test_mailer_as_root_exit_span
    ::Instana.config[:allow_exit_as_root] = true
    TestMailer.sample_email.deliver_now
    ::Instana.config[:allow_exit_as_root] = false

    queued_spans = Instana.processor.queued_spans
    assert_equal 1, queued_spans.length
    mail_span = queued_spans[0]

    assert_equal :"mail.actionmailer", mail_span[:n]
    assert_equal 'RailsActionMailerTest::TestMailer', mail_span[:data][:actionmailer][:class]
    assert_equal 'sample_email', mail_span[:data][:actionmailer][:method]
  end
end
