module GlobalIdHack
  def self.encode_transaction(id)
    Base64.strict_encode64("transaction_#{id}")
  end
end
