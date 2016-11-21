require_relative "../../test_helper"

class TestProxyRoutingAdmin < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_https_redirect
    response = Typhoeus.get("http://127.0.0.1:9080/admin/login", keyless_http_options)
    assert_equal(301, response.code, response.body)
    assert_equal("https://127.0.0.1:9081/admin/login", response.headers["location"])
  end

  def test_https_redirect_wildcard_host
    response = Typhoeus.get("http://127.0.0.1:9080/admin/login", keyless_http_options.deep_merge({
      :headers => {
        "Host" => "unknown.foo",
      },
    }))
    assert_equal(301, response.code, response.body)
    assert_equal("https://unknown.foo:9081/admin/login", response.headers["location"])
  end

  def test_missing_trailing_slash
    http_opts = keyless_http_options

    response = Typhoeus.get("http://127.0.0.1:9080/admin", http_opts)
    assert_equal(301, response.code, response.body)
    assert_equal("https://127.0.0.1:9081/admin", response.headers["location"])

    response = Typhoeus.get("https://127.0.0.1:9081/admin", http_opts)
    assert_equal(301, response.code, response.body)
    assert_equal("https://127.0.0.1:9081/admin/", response.headers["location"])
  end

  def test_missing_trailing_slash_wildcard_host
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "Host" => "unknown.foo",
      },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/admin", http_opts)
    assert_equal(301, response.code, response.body)
    assert_equal("https://unknown.foo:9081/admin", response.headers["location"])

    response = Typhoeus.get("https://127.0.0.1:9081/admin", http_opts)
    assert_equal(301, response.code, response.body)
    assert_equal("https://unknown.foo:9081/admin/", response.headers["location"])
  end

  def test_gives_precedence_to_admin_over_api_prefixes
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/admin/", :backend_prefix => "/info/" }],
      },
    ]) do
      response = Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options)
      assert_equal(200, response.code, response.body)
      assert_match("Admin Login", response.body)
    end
  end
end