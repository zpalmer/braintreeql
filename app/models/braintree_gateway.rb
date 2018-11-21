class BraintreeGateway
  LOGGER = ::Logger.new(STDOUT)
  ENDPOINT = "https://payments.sandbox.braintree-api.com/graphql"
  VERSION = "2018-09-12"
  PUBLIC_KEY = ENV["BT_PUBLIC_KEY"]
  PRIVATE_KEY = ENV["BT_PRIVATE_KEY"]

  def initialize(requester_class)
    @requester = requester_class.new(
      endpoint: ENDPOINT,
      headers: {
        "Braintree-Version" => VERSION
      },
      basic_auth: {
        :username => PUBLIC_KEY,
        :password => PRIVATE_KEY,
      }
    )
  end

  def client_token
    result = @requester.make_request("mutation { createClientToken(input: {}) { clientToken } }")
  end

  def transaction(payment_method_id, amount)
    query = <<~GRAPHQL
    mutation($input: ChargePaymentMethodInput!) {
      chargePaymentMethod(input: $input) {
        transaction {
          id
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

    @requester.make_request(query, variables)
  end

  def vault(single_use_payment_method_id)
    @requester.make_request(
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
          paymentMethodSnapshot {
            __typename
            ... on CreditCardDetails {
              bin
              last4
              expirationMonth
              expirationYear
              brandCode
              cardholderName
              binData {
                countryOfIssuance
              }
              origin {
                type
              }
            }
            ... on PayPalTransactionDetails {
              payer {
                email
                payerId
                firstName
                lastName
              }
              payerStatus
            }
          }
        }
      }
    }
    GRAPHQL
    @requester.make_request(query)
  end
end
