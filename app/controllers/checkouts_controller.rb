class CheckoutsController < ApplicationController
  TRANSACTION_SUCCESS_STATUSES = [
    "AUTHORIZED",
    "AUTHORIZING",
    "SETTLED",
    "SETTLEMENT_PENDING",
    "SETTLING",
    "SUBMITTED_FOR_SETTLEMENT",
  ]

  def new
    @client_token = gateway.client_token["data"]["createClientToken"]["clientToken"]
  end

  def show
    begin
      @transaction = gateway.node_fetch_transaction(params[:id]).fetch("data", {}).fetch("node")
      @result = _create_result_hash(@transaction)
    rescue BraintreeGateway::GraphQLError => error
      if error.message != nil and !error.messages.empty?
        flash[:error] = error.messages
      else
        flash[:error] = ["Something unexpected went wrong! Try again."]
      end
      redirect_to new_checkout_path
    end
  end

  def create
    amount = params["amount"] # In production you should not take amounts directly from clients
    nonce = params["payment_method_nonce"]

    begin
      result = gateway.transaction(nonce, amount)
      config.logger.log(Logger::DEBUG, result)

      if result["data"] && result["data"]["chargePaymentMethod"]
        redirect_to checkout_path(result["data"]["chargePaymentMethod"]["transaction"]["id"])
      else
        flash[:error] = ["Something unexpected went wrong! Try again."]
        redirect_to new_checkout_path
      end
    rescue BraintreeGateway::GraphQLError => error
      if error.messages != nil and !error.messages.empty?
        flash[:error] = error.messages
      else
        flash[:error] = ["Something unexpected went wrong! Try again."]
      end
      redirect_to new_checkout_path
    end
  end

  def _create_result_hash(transaction)
    status = transaction["status"]

    if TRANSACTION_SUCCESS_STATUSES.include? status
      result_hash = {
        :header => "Sweet Success!",
        :icon => "success",
        :message => "Your test transaction has been successfully processed. See the Braintree API response and try again."
      }
    else
      result_hash = {
        :header => "Transaction Unsuccessful",
        :icon => "fail",
        :message => "Your test transaction has a status of #{status}. See the Braintree API response and try again."
      }
    end
  end

  def gateway
    @gateway ||= BraintreeGateway.new
  end

  def old_gateway
    env = ENV["BT_ENVIRONMENT"]

    @old_gateway ||= Braintree::Gateway.new(
      :environment => env && env.to_sym,
      :merchant_id => ENV["BT_MERCHANT_ID"],
      :public_key => ENV["BT_PUBLIC_KEY"],
      :private_key => ENV["BT_PRIVATE_KEY"],
    )
  end
end
