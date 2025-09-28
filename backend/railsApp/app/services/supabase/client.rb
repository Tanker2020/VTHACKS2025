require "json"
require "net/http"
require "uri"

module Supabase
  class Error < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super("Supabase request failed (#{response.code}): #{response.body}")
    end
  end

  class Client
    DEFAULT_TIMEOUT = 15

    def initialize(base_url: ENV["SUPABASE_URL"], api_key: nil)
      api_key ||= ENV["SUPABASE_SERVICE_ROLE_KEY"]
      raise ArgumentError, "SUPABASE_URL is not configured" if base_url.blank?
      raise ArgumentError, "SUPABASE_SERVICE_ROLE_KEY is not configured" if api_key.blank?

      @base_url = base_url.chomp("/")
      @api_key = api_key
    end

    def get(path, params = {})
      request(Net::HTTP::Get, path, params: params)
    end

    def post(path, body = {}, params = {})
      request(Net::HTTP::Post, path, params: params, body: body)
    end

    def patch(path, body = {}, params = {})
      request(Net::HTTP::Patch, path, params: params, body: body)
    end

    def delete(path, params = {})
      request(Net::HTTP::Delete, path, params: params)
    end

    private

    def request(klass, path, params: {}, body: nil)
      uri = build_uri(path, params)
      req = klass.new(uri)
      decorate_headers(req, klass != Net::HTTP::Get)
      req.body = body.to_json if body.present?

      response = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_TIMEOUT) do |http|
        response = http.request(req)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise Supabase::Error.new(response)
      end

      parse_body(response.body)
    end

    def build_uri(path, params)
      uri = URI.parse("#{@base_url}/rest/v1/#{path}")
      uri.query = URI.encode_www_form(params) if params.present?
      uri
    end

    def decorate_headers(req, prefer_return)
      req["apikey"] = @api_key
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req["Prefer"] = "return=representation" if prefer_return
    end

    def parse_body(body)
      return {} if body.blank?
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
