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
    payment_data_hash = {
      reference_key: reference_key,
      amount: amount,
      note: note
    }
    return lookup_payment_idempotency_key(payment_data_hash)
  end


  # Helper functions for resolve()
  # ==============================

  def lookup_payment_idempotency_key(payment_data_hash)
    # New instances of the createPayment mutation will generate unique idempotency_key (UUID)
    idempotency_key = SecureRandom.uuid     # change this to a non-random String to test if idempotency_key match-found error is thrown (currently: yes!)
    
    # Check if idempotency_key already exists -- if so, transaction is a duplicate!
    pending_order_payment = PendingOrderPayment.find_by(idempotency_key: idempotency_key)
    if pending_order_payment

      # Payment already applied -- decline Payment!
      if pending_order_payment.status == "Successful"
        return {
          order: nil,
          errors: ["PendingOrderPayment with status '#{pending_order_payment.status}' and matching idempotency_key detected -- payment declined!"]
        }
      # Payment not applied -- retry updating Order's balance_due field
      elsif pending_order_payment.status == "Pending" || pending_order_payment.status == "Failed"
        return lookup_order_reference_key(payment_data_hash, idempotency_key: idempotency_key, pending_order_payment: pending_order_payment)
      end

    # No idempotency_key match found -- look up Order by reference_key to apply Payment
    else
      return lookup_order_reference_key(payment_data_hash, idempotency_key)
    end
  end


  def lookup_order_reference_key(payment_data_hash, idempotency_key, pending_order_payment: nil)
    order = Order.find_by(reference_key: payment_data_hash[:reference_key])

    # Order successfully found -- proceed to apply Payment
    if order
      return apply_payment_to_order(payment_data_hash, order, idempotency_key, pending_order_payment: pending_order_payment)

    # No Order found -- return errors
    else
      return {
        order: nil,
        errors: ["Order with reference_key #{reference_key} not found -- payment declined!"]
      }
    end
  end


  def apply_payment_to_order(payment_data_hash, order, idempotency_key, pending_order_payment: nil)
    # Create and save new Payment and PendingOrderPayment objects to database
    payment = Payment.create(amount: payment_data_hash[:amount], note: payment_data_hash[:note], idempotency_key: idempotency_key)
    if !pending_order_payment
      pending_order_payment = PendingOrderPayment.create(order_id: order.id, payment_id: payment.id, idempotency_key: idempotency_key, status: "Pending")
    end

    # Test if Payment will change Order's balance_due field by expected amount
    starting_balance = order.balance_due
    expected_balance = starting_balance - payment.amount

    # Set status to "Successful" (temporarily) to verify that its Amount is calculated in Order's balance_due field
    pending_order_payment.status = "Successful"
    pending_order_payment.save
    
    # If balance_due is expected value, return Order -- successfulPayments will include new Payment
    if order.balance_due == expected_balance
      return {
        order: order,
        errors: []
      }

    # balance_due is not expected value -- change status to "Failed" and decline Payment
    else
      pending_order_payment.status = "Failed"
      pending_order_payment.save
      return {
        order: nil,
        errors: ["Unexpected value for Order's balance_due field -- PendingOrderPayment status is now '#{pending_order_payment.status}' -- payment declined!"]
      }
    end
  end
end
