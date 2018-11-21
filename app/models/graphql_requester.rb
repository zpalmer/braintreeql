class GraphqlRequester
  include HTTParty
  format :json
  LOGGER = ::Logger.new(STDOUT)
  CONTENT_TYPE = "application/json"

  def initialize(endpoint:, headers: {}, basic_auth: {})
    @endpoint = endpoint
    @headers = {
      "Content-Type" => CONTENT_TYPE,
    }.merge(headers)
    @basic_auth = basic_auth
  end

  def ping
    make_request("{ ping }")
  end

  def make_request(query_string, variables_hash = {})
    payload = _generate_payload(query_string, variables_hash)
    raw_response = self.class.post(
      @endpoint,
      {
        :body => payload.to_s,
        :basic_auth => @basic_auth,
        :headers => @headers,
      }
    )
    # insert timeouts handling here
    result_hash = raw_response.parsed_response

    if result_hash["errors"] and !result_hash["data"]
      LOGGER.error("GraphQL request failed.\nresult: #{result_hash}\nrequest#{payload}")
      raise GraphqlError.new(result_hash["errors"])
    end

    return result_hash
  end

  def _generate_payload(query_string, variables_hash)
    JSON.generate({
      :query => query_string,
      :variables => variables_hash
    })
  end

  class GraphqlError < StandardError
    attr_reader :messages
    def initialize(result_errors_hash)
      messages = result_errors_hash.map { |error| error["message"] }
    end
  end
end
