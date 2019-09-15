module Types
  class OrderType < Types::BaseObject
    field :reference_key, String, null: false
    field :description, String, null: false
    field :total, Float, null: false
    field :successful_payments, [Types::PaymentType], null: false
    field :balance_due, Float, null: false
    # field :payments, [Types::PaymentType], null: false
    # field :pending_order_payments, [Types::PendingOrderPaymentType], null: false

    def successful_payments
      object.payments.successful
    end


    def balance_due
      balance = object.total
      
      if !object.payments.successful.empty?
        object.payments.successful.each do |payment|
          balance -= payment.amount
        end
      end

      if balance < 0
        balance = 0
      end

      return balance
    end


  end
end
