module Types
  class OrderType < Types::BaseObject
    field :reference_key, String, null: false
    field :description, String, null: false
    field :total, Float, null: false
    field :successful_payments, [Types::PaymentType], null: false
    field :balance_due, Float, null: false
    field :pending_payments, [Types::PaymentType], null: false
    field :failed_payments, [Types::PaymentType], null: false
    # field :payments, [Types::PaymentType], null: false
    # field :pending_order_payments, [Types::PendingOrderPaymentType], null: false


    def successful_payments
      object.payments.successful
    end

    def pending_payments
      object.payments.pending
    end

    def failed_payments
      object.payments.failed
    end


  end
end
