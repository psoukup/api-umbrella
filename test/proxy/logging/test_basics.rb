require_relative "../../test_helper"

class TestProxyLoggingBasics < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    setup_server
  end

  def test_logs_expected_fields_for_non_chunked_non_gzip
    param_url1 = "http%3A%2F%2Fexample.com%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    param_url2 = "%ED%A1%BC"
    param_url3_prefix = "https%3A//example.com/foo/"
    param_url3_invalid_suffix = "%D6%D0%B9%FA%BD%AD%CB%D5%CA%A1%B8%D3%D3%DC%CF%D8%D2%BB%C2%A5%C5%CC%CA%C0%BD%F5%BB%AA%B3%C7200%D3%E0%D2%B5%D6%F7%B9%BA%C2%F2%B5%C4%C9%CC%C6%B7%B7%BF%A3%AC%D2%F2%BF%AA%B7%A2%C9%CC%C5%DC%C2%B7%D2%D1%CD%A3%B9%A420%B8%F6%D4%C2%A3%AC%D2%B5%D6%F7%C4%C3%B7%BF%CE%DE%CD%FB%C8%B4%D0%E8%BC%CC%D0%F8%B3%A5%BB%B9%D2%F8%D0%D0%B4%FB%BF%EE%A1%A3%CF%F2%CA%A1%CA%D0%CF%D8%B9%FA%BC%D2%D0%C5%B7%C3%BE%D6%B7%B4%D3%B3%BD%FC2%C4%EA%CE%DE%C8%CB%B4%A6%C0%ED%A1%A3%D4%DA%B4%CB%B0%B8%D6%D0%A3%AC%CE%D2%C3%C7%BB%B3%D2%C9%D3%D0%C8%CB%CA%A7%D6%B0%E4%C2%D6%B0/sites/default/files/googleanalytics/ga.js"
    param_url3 = param_url3_prefix + param_url3_invalid_suffix

    url = "http://127.0.0.1:9080/api/logging-example/foo/bar/?unique_query_id=#{unique_test_id}&url1=#{param_url1}&url2=#{param_url2}&url3=#{param_url3}"
    response = Typhoeus.get(url, http_options.deep_merge({
      :headers => {
        "Accept" => "text/plain; q=0.5, text/html",
        "Accept-Encoding" => "compress, gzip",
        "Connection" => "close",
        "Content-Type" => "application/x-www-form-urlencoded",
        "Origin" => "http://foo.example",
        "User-Agent" => "curl/7.37.1",
        "Referer" => "http://example.com",
        "X-Forwarded-For" => "1.2.3.4, 4.5.6.7, 10.10.10.11, 10.10.10.10, 192.168.12.0, 192.168.13.255",
      },
      :userpwd => "basic-auth-username-example:my-secret-password",
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    assert_equal([
      "api_key",
      "backend_response_time",
      "gatekeeper_denied_code",
      "internal_gatekeeper_time",
      "proxy_overhead",
      "request_accept",
      "request_accept_encoding",
      "request_at",
      "request_basic_auth_username",
      "request_connection",
      "request_content_type",
      "request_hierarchy",
      "request_host",
      "request_ip",
      "request_ip_city",
      "request_ip_country",
      "request_ip_location",
      "request_ip_region",
      "request_method",
      "request_origin",
      "request_path",
      "request_query",
      "request_referer",
      "request_scheme",
      "request_size",
      "request_url",
      "request_user_agent",
      "request_user_agent_family",
      "request_user_agent_type",
      "response_age",
      "response_cache",
      "response_content_encoding",
      "response_content_length",
      "response_content_type",
      "response_server",
      "response_size",
      "response_status",
      "response_time",
      "response_transfer_encoding",
      "user_email",
      "user_id",
      "user_registration_source",
    ].sort, record.keys.sort)

    assert_equal(self.api_key, record["api_key"])
    assert_kind_of(Numeric, record["backend_response_time"])
    assert_kind_of(Numeric, record["internal_gatekeeper_time"])
    assert_kind_of(Numeric, record["proxy_overhead"])
    assert_kind_of(Numeric, record["proxy_overhead"])
    assert_equal("text/plain; q=0.5, text/html", record["request_accept"])
    assert_equal("compress, gzip", record["request_accept_encoding"])
    assert_kind_of(Numeric, record["request_at"])
    assert_match(/\A\d{13}\z/, record["request_at"].to_s)
    assert_equal("basic-auth-username-example", record["request_basic_auth_username"])
    assert_equal("close", record["request_connection"])
    assert_equal("application/x-www-form-urlencoded", record["request_content_type"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/logging-example/",
      "3/127.0.0.1:9080/api/logging-example/foo/",
      "4/127.0.0.1:9080/api/logging-example/foo/bar",
    ], record["request_hierarchy"])
    assert_equal("127.0.0.1:9080", record["request_host"])
    assert_equal("10.10.10.11", record["request_ip"])
    assert_equal("GET", record["request_method"])
    assert_equal("http://foo.example", record["request_origin"])
    assert_equal("/api/logging-example/foo/bar/", record["request_path"])
    assert_equal([
      "unique_query_id",
      "url1",
      "url2",
      "url3",
    ].sort, record["request_query"].keys.sort)
    assert_equal(unique_test_id, record["request_query"]["unique_query_id"])
    assert_equal(CGI.unescape(param_url1), record["request_query"]["url1"])
    assert_equal(param_url2, record["request_query"]["url2"])
    assert_equal(CGI.unescape(param_url3_prefix) + param_url3_invalid_suffix, record["request_query"]["url3"])
    assert_equal("http://example.com", record["request_referer"])
    assert_equal("http", record["request_scheme"])
    assert_kind_of(Numeric, record["request_size"])
    assert_equal(url, record["request_url"])
    assert_equal("curl/7.37.1", record["request_user_agent"])
    assert_equal("cURL", record["request_user_agent_family"])
    assert_equal("Library", record["request_user_agent_type"])
    # The age might be 1 second higher than the original response if the
    # response happens right on the boundary of a second.
    assert_operator(record["response_age"], :>=, 20)
    assert_operator(record["response_age"], :<=, 21)
    assert_equal("MISS", record["response_cache"])
    assert_equal("text/plain; charset=utf-8", record["response_content_type"])
    assert_equal("openresty", record["response_server"])
    assert_kind_of(Numeric, record["response_size"])
    assert_equal(200, record["response_status"])
    assert_kind_of(Numeric, record["response_time"])
    assert_kind_of(String, record["user_email"])
    assert_equal(self.api_user.email, record["user_email"])
    assert_kind_of(String, record["user_id"])
    assert_equal(self.api_user.id, record["user_id"])
    assert_equal("seed", record["user_registration_source"])
    assert_equal(5, record["response_content_length"])
  end

  def test_logs_extra_fields_for_chunked_or_gzip
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-delayed-chunked/5", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :accept_encoding => "gzip",
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("gzip", record["response_content_encoding"])
    assert_equal("chunked", record["response_transfer_encoding"])
  end

  def test_logs_accept_encoding_header_prior_to_normalization
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "Accept-Encoding" => "compress, gzip",
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("compress, gzip", record["request_accept_encoding"])
  end

  def test_logs_external_connection_header_not_internal
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "Connection" => "close",
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("close", record["request_connection"])
  end

  def test_logs_client_host_for_wildcard_domains
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello", http_options.deep_merge({
        :params => {
          :unique_query_id => unique_test_id,
        },
        :headers => {
          "Host" => "unknown.foo",
        },
      }))
      assert_equal(200, response.code, response.body)

      record = wait_for_log(unique_test_id)[:hit_source]
      assert_equal("unknown.foo", record["request_host"])
    end
  end

  def test_logs_request_schema_for_direct_hits
    response = Typhoeus.get("https://127.0.0.1:9081/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("https", record["request_scheme"])
  end

  def test_logs_request_schema_from_forwarded_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-Proto" => "https",
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("https", record["request_scheme"])
  end

  # For Elasticsearch 2 compatibility
  def test_requests_with_dots_in_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
        "foo.bar.baz" => "example.1",
        "foo.bar" => "example.2",
        "foo[bar]" => "example.3",
      },
    }))
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("example.1", record["request_query"]["foo_bar_baz"])
    assert_equal("example.2", record["request_query"]["foo_bar"])
    assert_equal("example.3", record["request_query"]["foo[bar]"])
  end

  def test_requests_with_duplicate_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?unique_query_id=#{unique_test_id}&test_dup_arg=foo&test_dup_arg=bar", http_options)
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal("foo,bar", record["request_query"]["test_dup_arg"])
  end

  def test_logs_request_at_as_date
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
    }))
    assert_equal(200, response.code, response.body)

    hit = wait_for_log(unique_test_id)[:hit]
    result = LogItem.gateway.client.indices.get_mapping({
      :index => hit["_index"],
      :type => hit["_type"],
    })

    property = result[hit["_index"]]["mappings"][hit["_type"]]["properties"]["request_at"]
    if($config["elasticsearch"]["api_version"] == 1)
      assert_equal({
        "type" => "date",
        "format" => "dateOptionalTime",
      }, property)
    elsif($config["elasticsearch"]["api_version"] >= 2)
      assert_equal({
        "type" => "date",
        "format" => "strict_date_optional_time||epoch_millis",
      }, property)
    else
      raise "Unknown elasticsearch version: #{$config["elasticsearch"]["api_version"].inspect}"
    end
  end

  def test_request_at_is_time_request_finishes_not_starts
    request_start = Time.now.utc
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/3000", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
    }))
    request_end = Time.now.utc
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]

    logged_response_time = record["response_time"]
    assert_operator(logged_response_time, :>=, 2500)
    assert_operator(logged_response_time, :<=, 3500)

    local_response_time = request_end - request_start
    assert_operator(local_response_time, :>=, 2.5)
    assert_operator(local_response_time, :<=, 3.5)

    assert_in_delta(request_end.to_f * 1000, record["request_at"], 500)
  end

  # Does not attempt to automatically map the first seen value into a date.
  def test_dates_in_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => "#{unique_test_id}-1",
        :date_field => "2010-05-01",
      },
    }))
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-1")[:hit_source]
    assert_equal("2010-05-01", record["request_query"]["date_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => "#{unique_test_id}-2",
        :date_field => "2010-05-0",
      },
    }))
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-2")[:hit_source]
    assert_equal("2010-05-0", record["request_query"]["date_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => "#{unique_test_id}-3",
        :date_field => "foo",
      },
    }))
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-3")[:hit_source]
    assert_equal("foo", record["request_query"]["date_field"])
  end

  # Does not attempt to automatically map the values into an array, which would
  # conflict with the first-seen string type.
  def test_duplicate_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?unique_query_id=#{unique_test_id}-1&test_dup_arg_first_string=foo", http_options)
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-1")[:hit_source]
    assert_equal("foo", record["request_query"]["test_dup_arg_first_string"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?unique_query_id=#{unique_test_id}-2&test_dup_arg_first_string=foo&test_dup_arg_first_string=bar", http_options)
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-2")[:hit_source]
    assert_equal("foo,bar", record["request_query"]["test_dup_arg_first_string"])
  end

  # Does not attempt to automatically map the first seen value into a boolean.
  def test_boolean_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?unique_query_id=#{unique_test_id}-1&test_arg_first_bool", http_options)
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-1")[:hit_source]
    assert_equal("true", record["request_query"]["test_arg_first_bool"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?unique_query_id=#{unique_test_id}-2&test_arg_first_bool=foo", http_options)
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-2")[:hit_source]
    assert_equal("foo", record["request_query"]["test_arg_first_bool"])
  end

  # Does not attempt to automatically map the first seen value into a number.
  def test_numbers_in_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => "#{unique_test_id}-1",
        :number_field => "123",
      },
    }))
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-1")[:hit_source]
    assert_equal("123", record["request_query"]["number_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => "#{unique_test_id}-2",
        :number_field => "foo",
      },
    }))
    assert_equal(200, response.code, response.body)
    record = wait_for_log("#{unique_test_id}-2")[:hit_source]
    assert_equal("foo", record["request_query"]["number_field"])
  end

  def test_logs_requests_that_time_out
    time_out_delay = $config["nginx"]["proxy_connect_timeout"] * 1000 + 3000
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/#{time_out_delay}", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
    }))
    assert_equal(504, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal(504, record["response_status"])
    assert_logs_base_fields(record, unique_test_id, api_user)
    assert_in_delta($config["nginx"]["proxy_connect_timeout"] * 1000, record["response_time"], 2000)
  end

  def test_logs_requests_that_are_canceled
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/2000", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :timeout => 0.5,
    }))
    assert(response.timed_out?)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal(499, record["response_status"])
    assert_logs_base_fields(record, unique_test_id, api_user)
  end

  def test_logs_cached_responses
    3.times do |index|
      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-expires/", http_options.deep_merge({
        :params => {
          :unique_query_id => unique_test_id,
        },
      }))
      assert_equal(200, response.code, response.body)
    end

    result = wait_for_log(unique_test_id, :min_result_count => 3)[:result]
    cache_results = {}
    result["hits"]["hits"].each do |hit|
      record = hit["_source"]
      assert_equal(200, record["response_status"])
      assert_logs_base_fields(record, unique_test_id, api_user)
      assert_kind_of(Numeric, record["response_age"])
      cache_results[record["response_cache"]] ||= 0
      cache_results[record["response_cache"]] += 1
    end
    assert_equal({
      "MISS" => 1,
      "HIT" => 2,
    }, cache_results)
  end

  def test_logs_denied_requests
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Api-Key" => "INVALID_KEY",
      },
    }))
    assert_equal(403, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal(403, record["response_status"])
    assert_logs_base_fields(record, unique_test_id)
    refute_logs_backend_fields(record)
    assert_equal("INVALID_KEY", record["api_key"])
    assert_equal("api_key_invalid", record["gatekeeper_denied_code"])
    refute(record["user_email"])
    refute(record["user_id"])
    refute(record["user_registration_source"])
  end

  def test_logs_requests_when_backend_is_down
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9450 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/down", :backend_prefix => "/down" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/down", http_options.deep_merge({
        :params => {
          :unique_query_id => unique_test_id,
        },
      }))
      assert_equal(502, response.code, response.body)

      record = wait_for_log(unique_test_id)[:hit_source]
      assert_equal(502, record["response_status"])
      assert_logs_base_fields(record, unique_test_id, api_user)
      assert_logs_backend_fields(record)
    end
  end

  def test_logs_requests_with_maximum_8kb_url_limit
    url_path = "/api/hello?unique_query_id=#{unique_test_id}&long="
    long_length = 8192 - "GET #{url_path} HTTP/1.1\r\n".length
    long_value = Faker::Lorem.characters(long_length)
    url = "http://127.0.0.1:9080#{url_path}#{long_value}"

    response = Typhoeus.get(url, http_options)
    assert_equal(200, response.code, response.body)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_equal(long_value, record["request_query"]["long"])
  end

  # We may actually want to revisit this behavior and log these requests, but
  # documenting current behavior.
  #
  # In order to log these requests, we'd need to move the log_by_lua_file
  # statement out of the "location" block and into the "http" level. We'd then
  # need to account for certain things in the logging logic that won't be
  # present in these error conditions.
  def test_does_not_log_requests_exceeding_8kb_url_limit
    url_path = "/api/hello?unique_query_id=#{unique_test_id}&long="
    long_length = 8193 - "GET #{url_path} HTTP/1.1\r\n".length
    long_value = Faker::Lorem.characters(long_length)
    url = "http://127.0.0.1:9080#{url_path}#{long_value}"

    response = Typhoeus.get(url, http_options)
    assert_equal(414, response.code, response.body)

    error = assert_raises do
      wait_for_log(unique_test_id)
    end
    assert_equal("Log not found: #{unique_test_id.inspect}", error.message)
  end

  def test_logs_long_url_and_headers_truncating_headers
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      url_path = "/#{unique_test_id}/logging-long-response-headers/?unique_query_id=#{unique_test_id}&long="
      long_length = 8192 - "GET #{url_path} HTTP/1.1\r\n".length
      long_value = Faker::Lorem.characters(long_length)
      url = "http://127.0.0.1:9080#{url_path}#{long_value}"

      response = Typhoeus.get(url, http_options.deep_merge({
        :headers => {
          "Accept" => Faker::Lorem.characters(1000),
          "Accept-Encoding" => Faker::Lorem.characters(1000),
          "Connection" => Faker::Lorem.characters(1000),
          "Content-Type" => Faker::Lorem.characters(1000),
          "Host" => Faker::Lorem.characters(1000),
          "Origin" => Faker::Lorem.characters(1000),
          "User-Agent" => Faker::Lorem.characters(1000),
          "Referer" => Faker::Lorem.characters(1000),
        },
        :userpwd => "#{Faker::Lorem.characters(1000)}:#{Faker::Lorem.characters(1000)}",
      }))
      assert_equal(200, response.code, response.body)

      record = wait_for_log(unique_test_id)[:hit_source]

      # Ensure the full URL got logged.
      assert_equal(long_value, record["request_query"]["long"])
      assert_match(long_value, record["request_url"])

      # Ensure the long header values got truncated so we're not susceptible to
      # exceeding rsyslog's message buffers and we're also not storing an
      # unexpected amount of data for values users can pass in.
      assert_equal(200, record["request_accept"].length, record["request_accept"])
      assert_equal(200, record["request_accept_encoding"].length, record["request_accept_encoding"])
      assert_equal(200, record["request_connection"].length, record["request_connection"])
      assert_equal(200, record["request_content_type"].length, record["request_content_type"])
      assert_equal(200, record["request_host"].length, record["request_host"])
      assert_equal(200, record["request_origin"].length, record["request_origin"])
      assert_equal(400, record["request_user_agent"].length, record["request_user_agent"])
      assert_equal(200, record["request_referer"].length, record["request_referer"])
      assert_equal(200, record["response_content_encoding"].length, record["response_content_encoding"])
      assert_equal(200, record["response_content_type"].length, record["response_content_type"])
    end
  end
end