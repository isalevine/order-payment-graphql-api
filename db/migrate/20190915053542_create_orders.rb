class CreateOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :orders do |t|
      t.string :description
      t.float :total
      t.string :reference_key

      t.timestamps
    end
  end
end
