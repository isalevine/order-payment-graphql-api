class ChangeColumnsToBeRequired < ActiveRecord::Migration[5.2]
  def change

    change_column_null :orders, :description, false
    change_column_null :orders, :total, false
    change_column_null :orders, :reference_key, false

    change_column_null :payments, :amount, false
    change_column_null :payments, :idempotency_key, false

    change_column_null :pending_order_payments, :order_id, false
    change_column_null :pending_order_payments, :payment_id, false
    change_column_null :pending_order_payments, :idempotency_key, false
    change_column_null :pending_order_payments, :status, false

  end
end
