require 'rails_helper'
require 'support/mock_data'

RSpec.describe CheckoutsController, type: :controller do
  render_views
  include_context 'mock_data'

  before do
    @mock_gateway = double("BraintreeGateway")
    allow(@mock_gateway).to receive(:client_token).and_return({
      "data" => {
        "createClientToken" => {
          "clientToken" => "your_client_token"
        }
      }
    })

    allow(BraintreeGateway).to receive(:new).and_return(@mock_gateway)
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "adds the Braintree client token to the page" do
      get :new
      expect(response.body).to match /your_client_token/
    end
  end

  describe "GET #show" do
    before do
      @mock_old_gateway = double("old_gateway")
      expect(Braintree::Gateway).to receive(:new).and_return(@mock_old_gateway)
    end

    it "returns http success" do
      allow(@mock_old_gateway).to receive_message_chain("transaction.find") { mock_transaction }

      get :show, id: "my_id"

      expect(response).to have_http_status(:success)
    end

    it "displays the transaction's fields" do
      allow(@mock_old_gateway).to receive_message_chain("transaction.find") { mock_transaction }

      get :show, id: "my_id"

      expect(response.body).to match /my_id/
      expect(response.body).to match /#{GlobalIdHack.encode_transaction("my_id")}/
      expect(response.body).to match /sale/
      expect(response.body).to match /10\.0/
      expect(response.body).to match /authorized/
      expect(response.body).to match /ijkl/
      expect(response.body).to match /545454/
      expect(response.body).to match /5454/
      expect(response.body).to match /MasterCard/
      expect(response.body).to match /12\/2015/
      expect(response.body).to match /Bill Billson/
      expect(response.body).to match /US/
      expect(response.body).to match /h6hh3j/
      expect(response.body).to match /Bill/
      expect(response.body).to match /Billson/
      expect(response.body).to match /bill@example.com/
      expect(response.body).to match /Billy Bobby Pins/
      expect(response.body).to match /bobby_pins.example.com/
      expect(response.body).to match /1234567890/
    end

    it "populates result object with success for a succesful transaction" do
      allow(@mock_old_gateway).to receive_message_chain("transaction.find") { mock_transaction }

      get :show, id: "my_id"

      expect(assigns(:result)).to eq({
        :header => "Sweet Success!",
        :icon => "success",
        :message => "Your test transaction has been successfully processed. See the Braintree API response and try again."
      })
    end


    it "populates result object with failure for a failed transaction" do
      allow(@mock_old_gateway).to receive_message_chain("transaction.find") { mock_failed_transaction }

      get :show, id: "my_id"

      expect(assigns(:result)).to eq({
        :header => "Transaction Failed",
        :icon => "fail",
        :message => "Your test transaction has a status of processor_declined. See the Braintree API response and try again."
      })
    end
  end

  describe "POST #create" do
    it "returns http success" do
      amount = "10.00"
      nonce = "fake-valid-nonce"

      allow(@mock_gateway).to receive(:transaction).and_return(
        mock_successful_graphql_transaction
      )

      post :create, payment_method_nonce: nonce, amount: amount

      expect(response).to redirect_to("/checkouts/#{id_for(mock_successful_graphql_transaction)}")
    end

    context "when there are processor errors" do
      it "redirects to the transaction page" do
        amount = "2001"
        nonce = "fake-valid-nonce"

        allow(@mock_gateway).to receive(:transaction).and_return(
          mock_processor_declined_graphql_transaction
        )

        post :create, payment_method_nonce: nonce, amount: amount

        expect(response).to redirect_to("/checkouts/#{id_for(mock_processor_declined_graphql_transaction)}")
      end
    end

    context "when braintree returns an error" do
      it "displays graphql errors" do
        amount = "nine and three quarters"
        nonce = "fake-valid-nonce"

        allow(@mock_gateway).to receive(:transaction).and_return(
          mock_transaction_graphql_error
        )

        post :create, payment_method_nonce: nonce, amount: amount

        expect(flash[:error]).to eq([
          "Error: Variable 'amount' has an invalid value. Values of type Amount must contain exactly 0, 2 or 3 decimal places."
        ])
      end

      it "displays validation errors" do
        amount = "9.75"
        nonce = "non-fake-invalid-nonce"

        allow(@mock_gateway).to receive(:transaction).and_return(
					mock_transaction_validation_error
        )

        post :create, payment_method_nonce: nonce, amount: amount

        expect(flash[:error]).to eq([
          "Error: Unknown or expired single use token ID.",
        ])
      end

      it "redirects to the new_checkout_path" do
        amount = "not_a_valid_amount"
        nonce = "not_a_valid_nonce"

        allow(@mock_gateway).to receive(:transaction).and_return(
          mock_transaction_graphql_error
        )

        post :create, payment_method_nonce: nonce, amount: amount

        expect(response).to redirect_to(new_checkout_path)
      end
    end
  end

  describe "POST#void" do
    before do
      @mock_old_gateway = double("old_gateway")
      expect(Braintree::Gateway).to receive(:new).and_return(@mock_old_gateway)
    end

    it "redirects to show the newly-voided transaction" do
      allow(@mock_old_gateway).to receive_message_chain("transaction.void") { mock_voided_transaction }
      voided_id = GlobalIdHack.encode_transaction(mock_voided_transaction.id)

      post :void, id: voided_id

      expect(response).to redirect_to("/checkouts/#{voided_id}}")
    end

  end
end
