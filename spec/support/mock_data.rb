RSpec.shared_context 'mock_data' do

  def id_for(transaction)
    GlobalIdHack.encode_transaction(transaction["data"]["createTransactionFromSingleUseToken"]["transaction"]["id"])
  end

  let(:mock_successful_graphql_transaction) {
    {
      "data" => {
        "createTransactionFromSingleUseToken" => {
          "transaction" => {
            "id" => "wstfgl",
            "amount" => "12.12",
            "status" => "SUBMITTED_FOR_SETTLEMENT",
            "gatewayRejectionReason" => nil,
            "processorResponse" => {
              "legacyCode" => "1000",
              "message" => "Approved",
              "cvvResponseCode" => "MATCHES",
              "avsPostalCodeResponseCode" => "MATCHES"
            }
          }
        }
      },
      "extensions" => {
        "requestId" => "abc-request-123-id"
      }
    }
  }

  let(:mock_processor_declined_graphql_transaction) {
    {
      "data" => {
        "createTransactionFromSingleUseToken" => {
          "transaction" => {
            "id" => "spaceodyssey",
            "amount" => "2001",
            "status" => "PROCESSOR_DECLINED",
            "gatewayRejectionReason" => nil,
            "processorResponse" => {
              "legacyCode" => "2001",
              "message" => "Insufficient Funds",
            }
          }
        }
      },
      "extensions" => {
        "requestId" => "def-request-456-id"
      }
    }
  }

  let(:mock_transaction_validation_error) {
    {
      "data" => {
        "createTransactionFromSingleUseToken" => nil,
      },
      "errors" => [
        {
          "message" => "Unknown or expired single use token ID.",
          "locations" => [
            {
              "line" => 2,
              "column" => 3
            }
          ],
          "path" => [
            "createTransactionFromSingleUseToken"
          ],
          "extensions" => {
            "errorType" => "user_error",
            "errorClass" => "VALIDATION",
            "legacyCode" => "91565",
            "inputPath" => [
              "input",
              "transaction",
              "singleUseTokenId"
            ]
          }
        }
      ],
      "extensions" => {
        "requestId" => "ghi-request-789-id"
      }
    }
  }

  let(:mock_transaction_graphql_error) {
    {
      "data" => nil,
      "errors" => [
        {
          "message" => "Variable 'amount' has an invalid value. Values of type Amount must contain exactly 0, 2 or 3 decimal places.",
          "locations" => [
            {
              "line" => 1,
              "column" => 11
            }
          ]
        }
      ],
      "extensions" => {
        "requestId" => "jkl-request-012-id"
      }
    }
  }

  let(:mock_transaction) {
    double(Braintree::Transaction,
      id: "my_id",
      type: "sale",
      amount: "10.0",
      status: "authorized",
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago,
      credit_card_details: double(
        token: "ijkl",
        bin: "545454",
        last_4: "5454",
        card_type: "MasterCard",
        expiration_date: "12/2015",
        cardholder_name: "Bill Billson",
        customer_location: "US",
      ),
      customer_details: double(
        id: "h6hh3j",
        first_name: "Bill",
        last_name: "Billson",
        email: "bill@example.com",
        company: "Billy Bobby Pins",
        website: "bobby_pins.example.com",
        phone: "1234567890",
        fax: nil,
      ),
    )
  }

  let(:mock_failed_transaction) {
    double(Braintree::Transaction,
      id: "my_id",
      type: "sale",
      amount: "10.0",
      status: "processor_declined",
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago,
      credit_card_details: double(
        token: "ijkl",
        bin: "545454",
        last_4: "5454",
        card_type: "MasterCard",
        expiration_date: "12/2015",
        cardholder_name: "Bill Billson",
        customer_location: "US",
      ),
      customer_details: double(
        id: "h6hh3j",
        first_name: "Bill",
        last_name: "Billson",
        email: "bill@example.com",
        company: "Billy Bobby Pins",
        website: "bobby_pins.example.com",
        phone: "1234567890",
        fax: nil,
      ),
    )
  }

  let(:sale_error_result) {
    double(Braintree::ErrorResult,
      success?: false,
      message: "Amount is an invalid format. Unknown payment_method_nonce.",
      transaction: nil,
      errors: [
        OpenStruct.new(code: 81503, message: "Amount is an invalid format."),
        OpenStruct.new(code: 91565, message: "Unknown payment_method_nonce."),
       ]
    )
  }

  let(:processor_declined_result) {
    double(Braintree::ErrorResult,
      success?: false,
      transaction: OpenStruct.new(status: "processor_declined", id: "my_id"),
    )
  }
end
