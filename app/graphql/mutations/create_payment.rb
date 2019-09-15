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


        # Is there a better way to organize + pass around Mutation arguments?
        paymentDataHash = {
            reference_key: reference_key,
            amount: amount,
            note: note
        }
        return lookupPaymentIdempotencyKey(paymentDataHash)
    end



    # Helper functions for resolve()

    def lookupPaymentIdempotencyKey(paymentDataHash)
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
            # Payment not applied -- retry updating Order's balance_due field
            elsif pendingOrderPayment.status == "Pending" || pendingOrderPayment.status == "Failed"
                return lookupOrderReferenceKey(paymentDataHash, idempotency_key: idempotency_key, pendingOrderPayment: pendingOrderPayment)
            end

        # No idempotency_key match found -- look up Order by reference_key to apply Payment
        else
            return lookupOrderReferenceKey(paymentDataHash, idempotency_key)
        end
    end


    def lookupOrderReferenceKey(paymentDataHash, idempotency_key, pendingOrderPayment: nil)
        order = Order.find_by(reference_key: paymentDataHash[:reference_key])

        # Order successfully found -- proceed to apply Payment
        if order
            return applyPaymentToOrder(paymentDataHash, order, idempotency_key, pendingOrderPayment: pendingOrderPayment)

        # No Order found -- return errors
        else
            return {
                order: nil,
                errors: ["Order with reference_key #{reference_key} not found -- payment declined!"]
            }
        end
    end


    def applyPaymentToOrder(paymentDataHash, order, idempotency_key, pendingOrderPayment: nil)
        # Create and save new Payment and PendingOrderPayment objects to database
        payment = Payment.create(amount: paymentDataHash[:amount], note: paymentDataHash[:note], idempotency_key: idempotency_key)
        if !pendingOrderPayment
            pendingOrderPayment = PendingOrderPayment.create(order_id: order.id, payment_id: payment.id, idempotency_key: idempotency_key, status: "Pending")
        end

        # Test if Payment will change Order's balance_due field by expected amount
        starting_balance = order.balance_due
        expected_balance = starting_balance - payment.amount

        # Set status to "Successful" (temporarily) to verify that its Amount is calculated in Order's balance_due field
        pendingOrderPayment.status = "Successful"
        pendingOrderPayment.save
        
        # If balance_due is expected value, return Order -- successfulPayments will include new Payment
        if order.balance_due == expected_balance
            return {
                order: order,
                errors: []
            }

        # balance_due is not expected value -- change status to "Failed" and decline Payment
        else
            pendingOrderPayment.status = "Failed"
            pendingOrderPayment.save
            return {
                order: nil,
                errors: ["Unexpected value for Order's balance_due field -- PendingOrderPayment status is now '#{pendingOrderPayment.status}' -- payment declined!"]
            }
        end
    end
end