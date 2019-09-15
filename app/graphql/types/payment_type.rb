module Types
  class PaymentType < Types::BaseObject
    field :amount, Float, null: false
    field :note, String, null: true
    field :createdAt, GraphQL::Types::ISO8601DateTime , null: false
  end
end
