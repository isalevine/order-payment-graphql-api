module Types
  class PendingOrderPaymentType < Types::BaseObject
    field :idempotency_key, String, null: false
    field :status, String, null:false
  end
end
