
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
    assert converted_id == "0000000000000000"

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
    assert converted_id.is_a?(Integer)
  end

  def test_header_to_id_conversion_with_bogus_header
    # Bogus nil arg
    bogus_result = Instana::Util.header_to_id(nil)
    assert_equal 0, bogus_result

    # Bogus Integer arg
    bogus_result = Instana::Util.header_to_id(1234)
    assert_equal 0, bogus_result

    # Bogus Array arg
    bogus_result = Instana::Util.header_to_id([1234])
    assert_equal 0, bogus_result
  end

  def test_id_conversion_back_and_forth
    # id --> header --> id
    original_id = ::Instana::Util.generate_id
    header_id = Instana::Util.id_to_header(original_id)
    converted_back_id = Instana::Util.header_to_id(header_id)
    assert original_id == converted_back_id

    # header --> id --> header
    original_header_id = "c025ee93b1aeda7b"
    id = Instana::Util.header_to_id(original_header_id)
    converted_back_header_id = Instana::Util.id_to_header(id)
    assert_equal original_header_id, converted_back_header_id
  end

  def test_id_max_value_and_conversion
    max_id = 9223372036854775807
    min_id = -9223372036854775808
    max_hex = "7fffffffffffffff"
    min_hex = "8000000000000000"

    assert_equal max_hex, Instana::Util.id_to_header(max_id)
    assert_equal min_hex, Instana::Util.id_to_header(min_id)

    assert_equal max_id, Instana::Util.header_to_id(max_hex)
    assert_equal min_id, Instana::Util.header_to_id(min_hex)
  end

end
