class Mutations::CreatePayment < Mutations::BaseMutation
    argument :reference_key, String, required: true
    argument :amount, Float, required: true
    argument :note, String, required: false

    field :order, Types::OrderType, null: false
    field :errors, [String], null: false

    def resolve(reference_key:, amount:, note:)
        # Check if idempotency_key exists -- if true, this is a duplicate Payment!
        idempotency_key = SecureRandom.uuid
        pendingOrderPayment = PendingOrderPayment.find_by(idempotency_key: idempotency_key)
        if pendingOrderPayment
            if pendingOrderPayment.status == "Successful"
                {
                    order: nil
                    errors: ["PendingOrderPayment with status '#{pendingOrderPayment.status}' and matching idempotency_key detected -- payment declined!"]
                }
            elsif pendingOrderPayment.status == "Pending" || pendingOrderPayment.status == "Failed"
                # Attempt to apply amount to Order's balanceDue again
            end
        
        else
            order = Order.find_by(reference_key: reference_key)
            if order
                # After order successfully found, create new pendingOrderPayment and proceed to apply amount to Order's balanceDue
                pendingOrderPayment = PendingOrderPayment.new(amount: amount, note: note, idempotency_key: idempotency_key, status: "Pending")
                if pendingOrderPayment.save
                   starting_balance = order.balance_due
                   expected_balance = starting_balance - pendingOrderPayment.amount

                   pendingOrderPayment.status = "Successful"
                   pendingOrderPayment.save         # Make an if statement that returns errors?
                   
                   if order.balance_due == expected_balance
                        {
                            order: order,
                            errors: []
                        }
                    else
                        pendingOrderPayment.status = "Failed"
                        pendingOrderPayment.save    # Make an if statement that returns errors?
                        return {
                            order: nil,
                            errors: ["Unexpected value for Order's balanceDue -- PendingOrderPayment status is now #{pendingOrderPayment.status} -- payment declined!"]
                        }
                    end

                   
                else 
                    {
                        order: nil
                        errors: pendingOrderPayment.errors.full_messages
                    }
                end

            else
                {
                    order: nil
                    errors: ["Order with reference_key #{reference_key} not found -- payment declined!"]
                }
            end


        # order = Order.new(description: description, total: total, reference_key: SecureRandom.uuid)
        # if order.save
        #     {
        #         order: order,
        #         errors: []
        #     }
        # else
        #     {
        #         order: nil,
        #         errors: order.errors.full_messages
        #     }
        # end
    end
end