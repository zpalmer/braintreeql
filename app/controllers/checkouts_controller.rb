class CheckoutsController < ApplicationController
  TRANSACTION_SUCCESS_STATUSES = [
    Braintree::Transaction::Status::Authorizing,
    Braintree::Transaction::Status::Authorized,
    Braintree::Transaction::Status::Settled,
    Braintree::Transaction::Status::SettlementConfirmed,
    Braintree::Transaction::Status::SettlementPending,
    Braintree::Transaction::Status::Settling,
    Braintree::Transaction::Status::SubmittedForSettlement,
  ]

  def new
    @client_token = gateway.client_token["data"]["createClientToken"]["clientToken"]
  end

  def show
    @transaction = old_gateway.transaction.find(params[:id])
    @result = _create_result_hash(@transaction)
    @voidable = [
      Braintree::Transaction::Status::Authorizing,
      Braintree::Transaction::Status::Authorized,
      Braintree::Transaction::Status::SubmittedForSettlement,
    ].include?(@transaction.status)
  end

  def create
    amount = params["amount"] # In production you should not take amounts directly from clients
    nonce = params["payment_method_nonce"]

    result = gateway.transaction(nonce, amount)

    if result["data"] && result["data"]["createTransactionFromSingleUseToken"]

      # hack to obtain GraphQL Global ID until it's returned from the API
      blue_public_id = result["data"]["createTransactionFromSingleUseToken"]["transaction"]["id"]
      global_id = GlobalIdHack.encode_transaction(blue_public_id)

      redirect_to checkout_path(global_id)
    elsif result["errors"]
      error_messages = result["errors"].map { |error| "Error: #{error['message']}" }
      flash[:error] = error_messages
      redirect_to new_checkout_path
    else
      flash[:error] = ["Something unexpected went wrong! Try again."]
      redirect_to new_checkout_path
    end
  end

  def void
    id = params["global_id"]
    old_gateway.transaction.void(id)

    redirect_to checkout_path(id)
  end

  def _create_result_hash(transaction)
    status = transaction.status

    if TRANSACTION_SUCCESS_STATUSES.include? status
      result_hash = {
        :header => "Sweet Success!",
        :icon => "success",
        :message => "Your test transaction has been successfully processed. See the Braintree API response and try again."
      }
    elsif status == Braintree::Transaction::Status::Voided
      result_hash = {
        :header => "Transaction Voided",
        :icon => "success",
        :message => "Your test transaction has been voided. See the Braintree API response and try again."
      }
    else
      result_hash = {
        :header => "Transaction Failed",
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
