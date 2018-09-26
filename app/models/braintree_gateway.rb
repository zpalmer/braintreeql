class BraintreeGateway
  include HTTParty
  format :json
  ENDPOINT = "https://payments.sandbox.braintree-api.com/graphql"
  VERSION = "2018-09-12"
  CONTENT_TYPE = "application/json"
  BASIC_AUTH_USERNAME = ENV["BT_PUBLIC_KEY"]
  BASIC_AUTH_PASSWORD = ENV["BT_PRIVATE_KEY"]


  def ping
    _make_request("{ ping }")
  end

  def client_token
    query_string = <<~GRAPHQL
      mutation {
        createClientToken(input: {}) {
          clientToken
        }
      }
      GRAPHQL
    _make_request(query: query_string)
  end

  def transaction(payment_method_id, amount)
    query_string = <<~GRAPHQL
      mutation($input: CreateTransactionFromSingleUseTokenInput!) {
        createTransactionFromSingleUseToken(input: $input) {
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
            paymentMethodDetails {
              ...on PayPalDetails {
                imageUrl
                payer {
                  email
                  firstName
                  lastName
                }
              }
              ...on CreditCardDetails {
                imageUrl
                last4
                brandCode
                cardholderName
              }
            }
          }
        }
      }
    GRAPHQL
    input_variables = {
      :input => {
        :singleUseTokenId => payment_method_id,
        :transaction => {
          :amount => amount,
        },
      }
    }
    _make_request(:query => query_string, :variables => input_variables)
  end

  def vault(single_use_payment_method_id)
    query_string = <<~GRAPHQL
      mutation($input: VaultPaymentMethodInput!) {
        vaultPaymentMethod(input: $input) {
          paymentMethod {
            id
            usage
          }
        }
      }
    GRAPHQL
    input_variables = {
      :input => {
        :paymentMethodId => single_use_payment_method_id,
      }
    }
    _make_request(:query => query_string, :variables => input_variables)
  end

  def _make_request(query:, variables: {})
    payload = _generate_payload(query, variables).to_s
    raw_response = self.class.post(
      ENDPOINT,
      {
        :body => payload,
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

  def _generate_payload(query_string, variables_hash)
    JSON.generate({
      :query => query_string,
      :variables => variables_hash
    })
  end
end
