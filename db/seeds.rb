Order.destroy_all
Payment.destroy_all
PendingOrderPayment.destroy_all


order1 = Order.create(description: "King of the Hill DVD", total: 100.00, reference_key: SecureRandom.uuid)
order2 = Order.create(description: "Mega Man 3 OST", total: 29.99, reference_key: SecureRandom.uuid)
order3 = Order.create(description: "Punch Out!! NES", total: 0.75, reference_key: SecureRandom.uuid)

payment1 = Payment.create(amount: 10.00, note: "First payment", idempotency_key: SecureRandom.uuid)
payment1 = Payment.create(amount: 10.00, note: "", idempotency_key: SecureRandom.uuid)
payment1 = Payment.create(amount: 10.00, idempotency_key: SecureRandom.uuid)

pending1 = PendingOrderPayment.create(order_id: order1.id, payment_id: payment1.id, idempotency_key: payment1.idempotency_key, status: "Successful")
pending2 = PendingOrderPayment.create(order_id: order2.id, payment_id: payment2.id, idempotency_key: payment2.idempotency_key, status: "Pending")
pending3 = PendingOrderPayment.create(order_id: order3.id, payment_id: payment3.id, idempotency_key: payment3.idempotency_key, status: "Failed")