module Types
  class MutationType < Types::BaseObject
    field :create_order, mutation: Mutations::CreateOrder
    field :create_payment, mutation: Mutations::CreatePayment
  end
end
