require 'spec_helper'
require 'rails_helper'

RSpec.describe CheckoutsController, type: :controller do
  render_views

  let!(:random) { Random.new }

  describe "GET #new" do
    it "retrieves the Braintree client token and adds it to the page" do
      get :new
      client_token = assigns(:client_token)
      expect(client_token).to_not be_nil
      expect(response.body).to match /#{client_token}/
    end
  end

  describe "GET #show" do
    let(:gateway) {
      Braintree::Gateway.new(
        :environment =>  ENV["BT_ENVIRONMENT"].to_sym,
        :merchant_id => ENV["BT_MERCHANT_ID"],
        :public_key => ENV["BT_PUBLIC_KEY"],
        :private_key => ENV["BT_PRIVATE_KEY"],
      )
    }

    it "retrieves the Braintree transaction and displays its attributes" do
      # Using a random amount to prevent duplicate checking errors
      amount = "#{random.rand(100)}.#{random.rand(100)}"
      result = BraintreeGateway.new(HTTParty).transaction("fake-valid-nonce", amount)
      expect(result["data"]["chargePaymentMethod"]).not_to be_nil

      transaction = result["data"]["chargePaymentMethod"]["transaction"]

      get :show, params: { id: transaction["id"] }

      expect(response).to have_http_status(:success)
      expect(response.body).to match Regexp.new(transaction["id"])
      expect(response.body).to match Regexp.new(amount)
      expect(response.body).to match "SUBMITTED_FOR_SETTLEMENT"
    end
  end

  describe "POST #create" do
    it "creates a transaction and redirects to checkouts#show" do
      amount = "#{random.rand(100)}.#{random.rand(100)}"
      post :create, params: { payment_method_nonce: "fake-valid-nonce", amount: amount }

      expect(response).not_to redirect_to(new_checkout_path)
      expect(response).to redirect_to(/\/checkouts\/[\w+]/)
    end

    context "when it's unsuccessful" do
      it "creates a transaction and displays status when there are processor errors" do
        amount = "2000"
        post :create, params: { payment_method_nonce: "fake-valid-nonce", amount: amount }

        expect(response).not_to redirect_to(new_checkout_path)
        expect(response).to redirect_to(/\/checkouts\/[\w+]/)
      end

      it "redirects to the new_checkout_path when the transaction was invalid" do
        amount = "#{random.rand(100)}.#{random.rand(100)}"
        post :create, params: { payment_method_nonce: "fake-consumed-nonce", amount: amount }

        expect(response).to redirect_to(new_checkout_path)
      end
    end
  end
end
