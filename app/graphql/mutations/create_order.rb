class Mutations::CreateOrder < Mutations::BaseMutation
    argument :description, String, required: true
    argument :total, Float, required: true

    field :order, Types::OrderType, null: false
    field :errors, [String], null: false

    def resolve(description:, total:)
        order = Order.new(description: description, total: total, reference_key: SecureRandom.uuid)
        if order.save
            {
                order: order,
                errors: []
            }
        else
            {
                order: nil,
                errors: order.errors. full_messages
            }
        end
    end
end