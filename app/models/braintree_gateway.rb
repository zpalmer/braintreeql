class BraintreeGateway
  include HTTParty
  format :json
  ENDPOINT = "https://payments.sandbox.braintree-api.com/graphql"
  VERSION = "2018-09-12"
  CONTENT_TYPE = "application/json"
  BASIC_AUTH_USERNAME = ENV["BT_PUBLIC_KEY"]
  BASIC_AUTH_PASSWORD = ENV["BT_PRIVATE_KEY"]


  def ping
    _make_request(JSON.generate({:query => "{ ping }"}))
  end

  def client_token
    _make_request(_generate_payload("mutation { createClientToken(input: {}) { clientToken } }"))
  end

  def transaction(payment_method_id, amount)
    transaction_payload = <<~GRAPHQL
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
    _make_request(_generate_payload(
      transaction_payload,
      {:input => {
        :paymentMethodId => payment_method_id,
        :transaction => {
          :amount => amount,
        },
      }}
    ))
  end

  def vault(single_use_payment_method_id)
    _make_request(_generate_payload(
      "mutation($input: VaultPaymentMethodInput!) { vaultPaymentMethod(input: $input) { paymentMethod { id usage } } }",
      {:input => {
        :paymentMethodId => single_use_payment_method_id,
      }}
    ))
  end

  def _generate_payload(query_string, variables_hash = {})
    JSON.generate({
      :query => query_string,
      :variables => variables_hash
    })
  end

  def _make_request(payload)
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
    return raw_response.parsed_response
  end
end
