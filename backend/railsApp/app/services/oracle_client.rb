require 'net/http'
require 'uri'
require 'openssl'

class OracleClient
  # Posts a list of uuids to the python compute endpoint.
  # Usage:
  #   OracleClient.post_uuids(['123','456'], url: ENV['ORACLE_URL'])

  def self.post_uuids(uuids, url: nil)
    raise ArgumentError, 'uuids must be an array' unless uuids.is_a?(Array)

    url ||= ENV['ORACLE_URL'] || 'http://localhost:5000/compute_and_send'
    uri = URI.parse(url)

    payload = { 'uuids' => uuids }
    raw = payload.to_json

    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'

    password = ENV.fetch('RECEIVE_PASSWORD', 'q7V;{X$og<^);g{&THeaB07u+-4-NPs{Hm4uMn*~6')
    req['Password'] = password

    shared_secret = ENV.fetch('SHARED_SECRET', 'dev-secret')
    begin
      sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), shared_secret.to_s, raw)
      req['X-Signature'] = "sha256=#{sig}"
    rescue => e
      Rails.logger.debug "Failed to sign payload: #{e.message}"
    end

    req.body = raw

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    resp = http.request(req)

    { code: resp.code.to_i, body: resp.body }
  end
end
