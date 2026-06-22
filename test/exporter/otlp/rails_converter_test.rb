# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/rails_converter'

class RailsConverterTest < Minitest::Test
  def test_action_controller_conversion
    span = create_span('actioncontroller', {
                         actioncontroller: { controller: 'UsersController', action: 'index' }
                       })
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'UsersController', attrs['code.namespace']
    assert_equal 'index', attrs['code.function']
  end

  def test_action_view_conversion
    span = create_span('actionview', {
                         actionview: { name: 'users/index.html.erb' }
                       })
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'users/index.html.erb', attrs['rails.view.name']
  end

  def test_render_conversion
    span = create_span('render', {
                         render: { type: 'partial', name: '_user.html.erb' }
                       })
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'partial', attrs['rails.render.type']
    assert_equal '_user.html.erb', attrs['rails.render.name']
  end

  def test_action_mailer_conversion
    span = create_span('mail.actionmailer', {
                         actionmailer: { class: 'UserMailer', method: 'welcome_email' }
                       })
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'UserMailer', attrs['code.namespace']
    assert_equal 'welcome_email', attrs['code.function']
  end

  def test_action_controller_with_nested_data
    span = create_span('actioncontroller', {})
    span[:actioncontroller] = { controller: 'PostsController', action: 'show' }
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'PostsController', attrs['code.namespace']
    assert_equal 'show', attrs['code.function']
  end

  def test_missing_data
    span = create_span('actioncontroller', {})
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  def test_unknown_span_type
    span = create_span('unknown', {})
    converter = Instana::Exporter::Otlp::RailsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name.to_sym)
    span[:data] = data unless data.empty?
    span.close
    span
  end
end
