module Types
  class MutationType < Types::BaseObject

    field :create_order, mutation: Mutations::CreateOrder
  
  end
end
