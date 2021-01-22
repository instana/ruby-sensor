
require 'test_helper'

class TracerIDMgmtTest < Minitest::Test
  def test_id_to_header_conversion
    # Test passing a standard Integer ID
    original_id = ::Instana::Util.generate_id
    converted_id = Instana::Util.id_to_header(original_id)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert !converted_id[/\H/]

    # Test passing a standard Integer ID as a String
    original_id = ::Instana::Util.generate_id
    converted_id = Instana::Util.id_to_header(original_id)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert !converted_id[/\H/]
  end

  def test_id_to_header_conversion_with_bogus_id
    # Test passing an empty String
    converted_id = Instana::Util.id_to_header('')

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == ''

    # Test passing a nil
    converted_id = Instana::Util.id_to_header(nil)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == ''

    # Test passing an Array
    converted_id = Instana::Util.id_to_header([])

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == ''
  end

  def test_header_to_id_conversion
    # Get a hex string to test against & convert
    header_id = Instana::Util.id_to_header(::Instana::Util.generate_id)
    converted_id = Instana::Util.header_to_id(header_id)

    # Assert that it is an Integer
    assert converted_id.is_a?(String)
  end

  def test_header_to_id_conversion_with_bogus_header
    # Bogus nil arg
    bogus_result = Instana::Util.header_to_id(nil)
    assert_equal '', bogus_result

    # Bogus Integer arg
    bogus_result = Instana::Util.header_to_id(1234)
    assert_equal '', bogus_result

    # Bogus Array arg
    bogus_result = Instana::Util.header_to_id([1234])
    assert_equal '', bogus_result
  end
end
