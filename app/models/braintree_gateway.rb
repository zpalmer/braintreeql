class BraintreeGateway
  include HTTParty
  format :json
  LOGGER = ::Logger.new(STDOUT)
  ENDPOINT = "https://payments.sandbox.braintree-api.com/graphql"
  VERSION = "2018-09-12"
  CONTENT_TYPE = "application/json"
  BASIC_AUTH_USERNAME = ENV["BT_PUBLIC_KEY"]
  BASIC_AUTH_PASSWORD = ENV["BT_PRIVATE_KEY"]

  def ping
    _make_request("{ ping }")
  end

  def client_token
    result = _make_request("mutation { createClientToken(input: {}) { clientToken } }")
  end

  def transaction(payment_method_id, amount)
    query = <<~GRAPHQL
    mutation($input: ChargePaymentMethodInput!) {
      chargePaymentMethod(input: $input) {
        transaction {
          id
          amount
          status
          gatewayRejectionReason
          processorResponse {
            legacyCode
            message
            cvvResponseCode
            avsPostalCodeResponseCode
          }
        }
      }
    }
    GRAPHQL
    variables = {
      :input => {
        :paymentMethodId => payment_method_id,
        :transaction => {
          :amount => amount,
        },
      }
    }

    _make_request(query, variables)
  end

  def vault(single_use_payment_method_id)
    _make_request(
      "mutation($input: VaultPaymentMethodInput!) { vaultPaymentMethod(input: $input) { paymentMethod { id usage } } }",
      {:input => {
        :paymentMethodId => single_use_payment_method_id,
      }}
    )
  end

  def node_fetch_transaction(transaction_id)
    query = <<~GRAPHQL
    query {
      node(id: "#{transaction_id}") {
        ... on Transaction {
          id
          amount
          status
          gatewayRejectionReason
          processorResponse {
            legacyCode
            message
            cvvResponseCode
            avsPostalCodeResponseCode
          }
        }
      }
    }
    GRAPHQL
    _make_request(query)
  end

  def _generate_payload(query_string, variables_hash)
    JSON.generate({
      :query => query_string,
      :variables => variables_hash
    })
  end

  def _make_request(query_string, variables_hash = {})
    payload = _generate_payload(query_string, variables_hash)
    raw_response = self.class.post(
      ENDPOINT,
      {
        :body => payload.to_s,
        :basic_auth => {
          :username => BASIC_AUTH_USERNAME,
          :password => BASIC_AUTH_PASSWORD,
        },
        :headers => {
          "Braintree-Version" => VERSION,
          "Content-Type" => CONTENT_TYPE,
        },
      }
    )
    # insert timeouts handling here
    result_hash = raw_response.parsed_response

    if result_hash["errors"] and !result_hash["data"]
      LOGGER.error("GraphQL request to Braintree failed.\nresult: #{result_hash}\nrequest#{payload}")
      raise GraphQLError.new(result_hash["errors"])
    end

    return result_hash
  end

  class GraphQLError < StandardError
    attr_reader :messages
    def initialize(result_errors_hash)
      messages = result_errors_hash.map { |error| error["message"] }
    end
  end
end
