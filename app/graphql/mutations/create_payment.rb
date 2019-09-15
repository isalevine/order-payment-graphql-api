class Mutations::CreatePayment < Mutations::BaseMutation
    argument :reference_key, String, required: true
    argument :amount, Float, required: true
    argument :note, String, required: false

    field :order, Types::OrderType, null: true
    field :errors, [String], null: false


    def resolve(reference_key:, amount:, note: nil)
        # Order (for successful payments):
        #   1. Check for existing idempotency_key
        #   2. Find Order by reference_key
        #   3. Create new Payment and PendingOrderPayment(status: "Pending")
        #   4. Calculate new expected_balance for Order's balance_due field
        #   5. Update PendingOrderPayment status to "Successful"
        #   6. Check if Order's updated balance_due matches expected_balance
        #   7. Return Order, with new Payment listed inside successful_payments field


        # New instances of the createPayment mutation will generate unique idempotency_key (UUID)
        idempotency_key = SecureRandom.uuid     # change this to a non-random String to test if idempotency_key match-found error is thrown (currently: yes!)
        

    
        # Check if idempotency_key already exists -- if so, transaction is a duplicate!
        pendingOrderPayment = PendingOrderPayment.find_by(idempotency_key: idempotency_key)
        if pendingOrderPayment

            # Payment already applied -- decline Payment!
            if pendingOrderPayment.status == "Successful"
                return {
                    order: nil,
                    errors: ["PendingOrderPayment with status '#{pendingOrderPayment.status}' and matching idempotency_key detected -- payment declined!"]
                }
            
            # Payment not applied -- retry updating Order's balanceDue
            elsif pendingOrderPayment.status == "Pending" || pendingOrderPayment.status == "Failed"
                # Attempt to apply amount to Order's balanceDue again => MODULARIZE!
            end


        # No idempotency_key match found -- look up Order by reference_key to apply Payment
        else
            order = Order.find_by(reference_key: reference_key)

            # Order successfully found -- create new Payment and PendingOrderPayment,
            # and test if Payment will change Order's balanceDue by expected amount
            if order
                payment = Payment.create(amount: amount, note: note, idempotency_key: idempotency_key)
                pendingOrderPayment = PendingOrderPayment.create(order_id: order.id, payment_id: payment.id, idempotency_key: idempotency_key, status: "Pending")
                
                starting_balance = order.balance_due
                expected_balance = starting_balance - payment.amount

                pendingOrderPayment.status = "Successful"
                pendingOrderPayment.save
                
                # If balanceDue is expected value, return Order -- successfulPayments will include new Payment
                if order.balance_due == expected_balance
                    return {
                        order: order,
                        errors: []
                    }

                # balanceDue is not expected value -- change status to "Failed" and decline Payment
                else
                    pendingOrderPayment.status = "Failed"
                    pendingOrderPayment.save
                    return {
                        order: nil,
                        errors: ["Unexpected value for Order's balanceDue -- PendingOrderPayment status is now '#{pendingOrderPayment.status}' -- payment declined!"]
                    }
                end


            # No Order found
            else
                return {
                    order: nil,
                    errors: ["Order with reference_key #{reference_key} not found -- payment declined!"]
                }
            end

        end

    end
end