class Mutations::CreatePayment < Mutations::BaseMutation
    argument :reference_key, String, required: true
    argument :amount, Float, required: true
    argument :note, String, required: false

    field :order, Types::OrderType, null: true
    field :errors, [String], null: false

    def resolve(reference_key:, amount:, note: nil)
        # Check if idempotency_key exists -- if true, this is a duplicate Payment!
        idempotency_key = SecureRandom.uuid
        pendingOrderPayment = PendingOrderPayment.find_by(idempotency_key: idempotency_key)
        if pendingOrderPayment
            if pendingOrderPayment.status == "Successful"
                return {
                    order: nil,
                    errors: ["PendingOrderPayment with status 'Successful' and matching idempotency_key detected -- payment declined!"]
                }
            elsif pendingOrderPayment.status == "Pending" || pendingOrderPayment.status == "Failed"
                # Attempt to apply amount to Order's balanceDue again
            end
        
        else
            order = Order.find_by(reference_key: reference_key)
            if order
                # After order successfully found, create new Payment and pendingOrderPayment, and proceed to apply amount to Order's balanceDue
                payment = Payment.create(amount: amount, note: note, idempotency_key: idempotency_key)
                pendingOrderPayment = PendingOrderPayment.create(order_id: order.id, payment_id: payment.id, idempotency_key: idempotency_key, status: "Pending")
                
                starting_balance = order.balance_due
                expected_balance = starting_balance - payment.amount

                pendingOrderPayment.status = "Successful"
                pendingOrderPayment.save         # Make an if statement that returns errors?
                
                if order.balance_due == expected_balance
                    return {
                        order: order,
                        errors: []
                    }
                else
                    pendingOrderPayment.status = "Failed"
                    pendingOrderPayment.save    # Make an if statement that returns errors?
                    return {
                        order: nil,
                        errors: ["Unexpected value for Order's balanceDue -- PendingOrderPayment status is now 'Failed' -- payment declined!"]
                    }
                end

            else
                return {
                    order: nil,
                    errors: ["Order with reference_key #{reference_key} not found -- payment declined!"]
                }
            end
        end

    end
end