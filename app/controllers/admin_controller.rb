class AdminController < ApplicationController
  def index
    if params.keys.include?("currency")
      show_transactions_with_currency
    elsif params.keys.include?("status")
      show_transactions_with_status(params[:status])
    else
      @transactions = gateway.node_fetch_many_transactions(stupid_hack_for_search_latest).fetch("data", {}).values
    end
  end

  def show_transactions_with_status(status)
    case status
    when "gateway_rejected"
      @status_name = "Gateway Rejected"
      fields = BraintreeGateway.transaction_gateway_rejected_fields
    when "processor_declined"
      @status_name = "Processor Declined"
      fields = BraintreeGateway.transaction_processor_declined_fields
    else
      fields = "id status amount"
    end
    @transactions = gateway.node_fetch_many_transactions(stupid_hack_for_search_status(status), fields).fetch("data", {}).values
    render :status
  end

  def show_transactions_with_currency
    @transactions = gateway.node_fetch_many_transactions(stupid_hack_for_search_latest, BraintreeGateway.transaction_currency_fields).fetch("data", {}).values
    render :currency
  end

  def stupid_hack_for_search_status(status)
    blue_ids = []
    @max_number_of_ids_requestable_at_once = 8

    #check status is in acceptable statuses
    blue_ids = old_gateway.transaction.search do |search|
      search.type.is Braintree::Transaction::Type::Sale
      search.status.is status
    end.ids

    ids = blue_ids.take(@max_number_of_ids_requestable_at_once).map { |id| Base64.urlsafe_encode64("transaction_#{id}", padding: false) }
  end

  def stupid_hack_for_search_latest
    blue_ids = []
    search_window_start, search_window_end = [Time.now - 60*60*24*14, Time.now]
    @max_number_of_ids_requestable_at_once = 8

    while blue_ids.length < @max_number_of_ids_requestable_at_once
      blue_ids += old_gateway.transaction.search do |search|
        search.created_at.between(search_window_start, search_window_end)
        search.type.is Braintree::Transaction::Type::Sale
      end.ids
      search_window_start_inclusive, search_window_end = [search_window_end - 1, search_window_end - 60*60*24*14 - 1]
    end

    ids = blue_ids.take(@max_number_of_ids_requestable_at_once).map { |id| Base64.urlsafe_encode64("transaction_#{id}", padding: false) }
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

  def gateway
    @gateway ||= BraintreeGateway.new
  end
end
