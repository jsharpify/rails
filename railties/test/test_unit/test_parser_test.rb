# frozen_string_literal: true

require "active_support/deprecator"
require "active_support/test_case"
require "active_support/testing/autorun"
require "minitest/mock"
require "rails/test_unit/test_parser"

class TestParserTestFixture < ActiveSupport::TestCase
  def test_method
    assert true

    assert true
  end

  def test_oneline; assert true; end

  test "declarative" do
    assert true

    assert true
  end

  test("declarative w/parens") do
    assert true
  end

  self.test "declarative explicit receiver" do
    assert true

    assert true
  end

  test("declarative oneline") { assert true }

  test("declarative oneline do") do assert true end

  test("declarative multiline w/ braces") {
    assert true
    assert_not false
  }

  # Check that extensions can provide aliases for testing methods
  def self.my_testing_alias(test_name, &)
    define_method(:"test_#{test_name}", &)
  end

  my_testing_alias("method_alias") { assert true }
end

class TestParserTest < ActiveSupport::TestCase
  def test_parser
    actual =
      TestParserTestFixture
        .instance_methods(false)
        .map { |method| TestParserTestFixture.instance_method(method) }
        .sort_by { |method| method.source_location[1] }
        .map { |method| [method.name, *Rails::TestUnit::TestParser.definition_for(method)] }

    expected = [
      [:test_method, __FILE__, 9..13],
      [:test_oneline, __FILE__, 15..15],
      [:test_declarative, __FILE__, 17..21],
      [:"test_declarative_w/parens", __FILE__, 23..25],
      [:test_declarative_explicit_receiver, __FILE__, 27..31],
      [:test_declarative_oneline, __FILE__, 33..33],
      [:test_declarative_oneline_do, __FILE__, 35..35],
      [:"test_declarative_multiline_w/_braces", __FILE__, 37..40],
      [:"test_method_alias", __FILE__, 47..47],
    ]

    assert_equal expected, actual
  end

  def test_parser_only_parses_file_once
    method_used_to_cache_result = :test_method
    another_test_in_fixture = :test_oneline

    cached_parsed_result = Rails::TestUnit::TestParser.definition_for(
      TestParserTestFixture.instance_method(method_used_to_cache_result)
    )

    prism_calls = 0
    original_parse_file = Prism.method(:parse_file)
    Prism.stub(:parse_file, ->(file) { prism_calls += 1; original_parse_file.call(file) }) do
      same_method_result = Rails::TestUnit::TestParser.definition_for(
        TestParserTestFixture.instance_method(method_used_to_cache_result)
      )
      different_method_result = Rails::TestUnit::TestParser.definition_for(
        TestParserTestFixture.instance_method(another_test_in_fixture)
      )

      assert_equal 0, prism_calls
      assert_equal cached_parsed_result, same_method_result
      assert_equal cached_parsed_result.first, different_method_result.first
      assert_not_equal cached_parsed_result.last, different_method_result.last
    end
  end
end
