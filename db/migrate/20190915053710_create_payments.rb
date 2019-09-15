class CreatePayments < ActiveRecord::Migration[5.2]
  def change
    create_table :payments do |t|
      t.float :amount
      t.string :note
      t.string :idempotency_key

      t.timestamps
    end
  end
end
