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
      @transaction = gateway.node_fetch_transaction(params[:id]).fetch("data", {})["transaction"]
      @result = _create_result_hash(@transaction)
    rescue BraintreeGateway::GraphQLError => error
      if error.messages != nil and !error.messages.empty?
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
      id = _get_id_from_transaction_result(result)

      if id
        redirect_to checkout_path(id)
      else
        raise BraintreeGateway::GraphQLError.new()
      end
    rescue BraintreeGateway::GraphQLError => error
      if error.messages != nil and !error.messages.empty?
        flash[:error] = error.messages
      else
        flash[:error] = ["Error: Something unexpected went wrong! Try again."]
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

  def _get_id_from_transaction_result(result)
    if result["data"]
      if result["data"]["chargePaymentMethod"]
        if result["data"]["chargePaymentMethod"]["transaction"]
          return result["data"]["chargePaymentMethod"]["transaction"]["id"]
        end
      end
    end
  end

  def gateway
    @gateway ||= BraintreeGateway.new(HTTParty)
  end
end
