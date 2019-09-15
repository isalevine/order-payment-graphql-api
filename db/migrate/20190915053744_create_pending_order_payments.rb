class CreatePendingOrderPayments < ActiveRecord::Migration[5.2]
  def change
    create_table :pending_order_payments do |t|
      t.integer :order_id
      t.integer :payment_id
      t.string :idempotency_key
      t.string :status

      t.timestamps
    end
  end
end
