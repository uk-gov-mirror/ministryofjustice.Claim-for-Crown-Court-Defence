# class used to smoke test the Restful API
#
# The claim creation process uses the dropdown data endpoints
# thereby double checking that those endpoints are working and
# their values are valid for claim creation or associated records.
#
# example:
# ---------------------------------------
#   api_client = ApiTestClient.new()
#   api_client.run
#   if api_client.failure
#     puts "failed"
#     puts api_client.full_error_messages.join("/n")
#   end
# ---------------------------------------
#
# To debug any test:
#
# debug('my debug statement', :red)
#

require 'caching/api_request'
require 'rest-client'
Dir[File.join(Rails.root, 'spec', 'support', 'api', 'claims', '*.rb')].each { |file| require file }

class ApiTestClient
  include Debuggable

  attr_reader :success, :full_error_messages, :messages

  EXTERNAL_USER_PREFIX = 'api/external_users'.freeze

  def initialize
    @full_error_messages = []
    @messages = []
    @success = true
  end

  def run
    AdvocateClaimTest.new(client: self).test_creation!
    AdvocateInterimClaimTest.new(client: self).test_creation!
    AdvocateSupplementaryClaimTest.new(client: self).test_creation!
    AdvocateHardshipClaimTest.new(client: self).test_creation!
    LitigatorFinalClaimTest.new(client: self).test_creation!
    LitigatorInterimClaimTest.new(client: self).test_creation!
    LitigatorTransferClaimTest.new(client: self).test_creation!
    LitigatorHardshipClaimTest.new(client: self).test_creation!
  end

  def run_debug_session
    DebugFinalClaimTest.new(client: self).test_creation!
  end

  def failure
    !@success
  end

  def post_to_endpoint(resource, payload, debug = false)
    endpoint = RestClient::Resource.new([api_root_url, EXTERNAL_USER_PREFIX, resource].join('/'))
    debug("POSTING TO #{endpoint}") if debug
    debug("Payload:\n#{payload}\n") if debug

    endpoint.post(payload.to_json, content_type: :json, accept: :json) do |response, _request, _result|
      debug("Code: #{response.code}") if debug
      debug("Body:\n#{response.body}\n") if debug
      handle_response(response, resource)
      response
    end
  end

  def post_to_endpoint_with_debug(resource, payload)
    post_to_endpoint(resource, payload, true)
  end

  #
  # don't raise exceptions but, instead, return the
  # response for analysis.
  #
  def get_dropdown_endpoint(resource, api_key, params = {})
    query_params = '?' + params.merge(api_key: api_key).to_query
    endpoint = RestClient::Resource.new([api_root_url, 'api', resource].join('/') + query_params)

    Caching::ApiRequest.cache(endpoint.url) do
      endpoint.get do |response, _request, _result|
        handle_response(response, resource)
        response
      end
    end
  end

  private

  def handle_response(response, resource)
    return if response.code.to_s =~ /^2/
    @success = false
    @full_error_messages << "#{resource} Endpoint raised error - #{response}"
  end

  def api_root_url
    GrapeSwaggerRails.options.app_url
  end
end
