require_relative "../../test_helper"

class TestProxyLoggingSpecialChars < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    setup_server
  end

  # To account for JSON escaping in nginx logs.
  def test_logs_headers_with_quotes
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "Referer" => "http://example.com/\"foo'bar",
        "Content-Type" => "text\"\x22plain'\\x22",
      },
      :userpwd => "\"foo'bar:bar\"foo'",
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("http://example.com/\"foo'bar", record["request_referer"])
    assert_equal("text\"\"plain'\\x22", record["request_content_type"])
    assert_equal("\"foo'bar", record["request_basic_auth_username"])
  end

  def test_logs_headers_with_special_chars
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "Referer" => "http://example.com/!\\*^%#[]",
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("http://example.com/!\\*^%#[]", record["request_referer"])
  end

  def test_logs_utf8_urls
    url = "http://127.0.0.1:9080/api/hello/utf8/✓/encoded_utf8/%E2%9C%93/?unique_query_id=#{unique_test_id}&utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xC2\xAC\xC2\xB6\xC2\xAA\xC3\xBE\xC2\xA4l&more_utf8_hex_lowercase=\xc2\xac\xc2\xb6\xc2\xaa\xc3\xbe\xc2\xa4l&actual_backslash_x=\\xC2\\xAC\\xC2\\xB6\\xC2\\xAA\\xC3\\xBE\\xC2\\xA4l"
    response = Typhoeus.get(url, http_options)
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("%E2%9C%93", record["request_query"]["utf8"])
    assert_equal("%E2%9C%93", record["request_query"]["utf8_url_encoded"])
    assert_equal("%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l", record["request_query"]["more_utf8"])
    assert_equal("%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l", record["request_query"]["more_utf8_hex"])
    assert_equal("%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l", record["request_query"]["more_utf8_hex_lowercase"])
    assert_equal("\\xC2\\xAC\\xC2\\xB6\\xC2\\xAA\\xC3\\xBE\\xC2\\xA4l", record["request_query"]["actual_backslash_x"])
    assert_equal("/api/hello/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/", record["request_path"])
    assert_equal("http://127.0.0.1:9080/api/hello/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/?unique_query_id=#{unique_test_id}&utf8=%E2%9C%93&utf8_url_encoded=%E2%9C%93&more_utf8=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex_lowercase=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&actual_backslash_x=\\xC2\\xAC\\xC2\\xB6\\xC2\\xAA\\xC3\\xBE\\xC2\\xA4l", record["request_url"])
  end

  def test_valid_utf8_encoding_in_url_path_url_params_headers
    # Test various encodings of the UTF-8 pound symbol: £
    url_encoded = "%C2%A3"
    base64ed = "wqM="
    raw = "£"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{raw}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{raw}", http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
        "Referer" => base64ed,
        "Origin" => raw,
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    # When in the URL path or query string, we expect the raw £ symbol to be
    # logged as the url encoded version.
    expected_raw_in_url = url_encoded

    # URL query string
    assert_equal(url_encoded, record["request_query"]["url_encoded"])
    assert_equal(base64ed, record["request_query"]["base64ed"])
    assert_equal(expected_raw_in_url, record["request_query"]["raw"])

    # URL path
    assert_equal("/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/", record["request_path"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/hello/",
      "3/127.0.0.1:9080/api/hello/#{url_encoded}/",
      "4/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/",
      "5/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}",
    ], record["request_hierarchy"])

    # Full URL
    assert_equal("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{expected_raw_in_url}", record["request_url"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
    assert_equal(base64ed, record["request_referer"])
    assert_equal(raw, record["request_origin"])
  end

  def test_invalid_utf8_encoding_in_url_path_url_params_headers
    # Test various encodings of the ISO-8859-1 pound symbol: £ (but since this
    # is the ISO-8859-1 version, it's not valid UTF-8).
    url_encoded = "%A3"
    base64ed = "ow=="
    raw = Base64.decode64(base64ed).force_encoding("utf-8")
    raw_utf8 = Base64.decode64(base64ed).encode("utf-8", :invalid => :replace, :undef => :replace)
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{raw}/#{raw_utf8}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{raw}&raw_utf8=#{raw_utf8}", http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
        "Referer" => base64ed,
        "Origin" => raw,
        "Accept" => raw_utf8,
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    # Since the encoding of this string wasn't actually a valid UTF-8 string,
    # we test situations where it's sent as the raw ISO-8859-1 value, as well
    # as the UTF-8 replacement character.
    expected_raw_in_url = url_encoded
    expected_raw_in_header = ""
    expected_raw_utf8_in_url = "%EF%BF%BD"
    expected_raw_utf8_in_header = Base64.decode64("77+9").force_encoding("utf-8")

    # URL query string
    assert_equal(url_encoded, record["request_query"]["url_encoded"])
    assert_equal(base64ed, record["request_query"]["base64ed"])
    assert_equal(expected_raw_in_url, record["request_query"]["raw"])
    assert_equal(expected_raw_utf8_in_url, record["request_query"]["raw_utf8"])

    # URL path
    assert_equal("/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/#{expected_raw_utf8_in_url}/", record["request_path"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/hello/",
      "3/127.0.0.1:9080/api/hello/#{url_encoded}/",
      "4/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/",
      "5/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/",
      "6/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/#{expected_raw_utf8_in_url}",
    ], record["request_hierarchy"])

    # Full URL
    assert_equal("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url}/#{expected_raw_utf8_in_url}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{expected_raw_in_url}&raw_utf8=#{expected_raw_utf8_in_url}", record["request_url"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
    assert_equal(base64ed, record["request_referer"])
    assert_equal(expected_raw_in_header, record["request_origin"])
    assert_equal(expected_raw_utf8_in_header, record["request_accept"])
  end

  def test_decodes_url_encoding_in_request_query_not_others
    url_encoded = "http%3A%2F%2Fexample.com%2Fsub%2Fsub%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}", http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    # URL query string
    assert_equal(CGI.unescape(url_encoded), record["request_query"]["url_encoded"])

    # URL path
    assert_equal("/api/hello/#{url_encoded}/", record["request_path"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/hello/",
      "3/127.0.0.1:9080/api/hello/#{url_encoded}",
    ], record["request_hierarchy"])

    # Full URL
    assert_equal("http://127.0.0.1:9080/api/hello/#{url_encoded}/?unique_query_id=#{unique_test_id}&url_encoded=#{url_encoded}", record["request_url"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
  end

  def test_optionally_encodable_ascii_strings_as_given_except_in_request_query
    as_is = "-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{as_is}/?unique_query_id=#{unique_test_id}&as_is=#{as_is}", http_options.deep_merge({
      :headers => {
        "Content-Type" => as_is,
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    # URL query string
    assert_equal(CGI.unescape(as_is), record["request_query"]["as_is"])

    # URL path
    assert_equal("/api/hello/#{as_is}/", record["request_path"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/hello/",
      "3/127.0.0.1:9080/api/hello/-%2D ;%3B +%2B /",
      "4/127.0.0.1:9080/api/hello/-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B",
    ], record["request_hierarchy"])

    # Full URL
    assert_equal("http://127.0.0.1:9080/api/hello/#{as_is}/?unique_query_id=#{unique_test_id}&as_is=#{as_is}", record["request_url"])

    # HTTP headers
    assert_equal(as_is, record["request_content_type"])
  end

  def test_slashes_and_backslashes
    url = "http://127.0.0.1:9080/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash?&unique_query_id=#{unique_test_id}&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C"
    response = Typhoeus.get(url, http_options)
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("/slash", record["request_query"]["forward_slash"])
    assert_equal("/", record["request_query"]["encoded_forward_slash"])
    assert_equal("\\", record["request_query"]["back_slash"])
    assert_equal("\\", record["request_query"]["encoded_back_slash"])
    assert_equal("/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash", record["request_path"])
    assert_equal(url, record["request_url"])
  end
end