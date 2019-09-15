module Types
  class PaymentType < Types::BaseObject
    field :amount, Float, null: false
    field :note, String, null: true
  end
end
