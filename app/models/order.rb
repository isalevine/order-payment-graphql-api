class Order < ApplicationRecord
    has_many :pending_order_payments

    # suggestion per: https://stackoverflow.com/a/9547179
    has_many :payments, through: :pending_order_payments do
        def successful
            where("pending_order_payments.status = ?", "Successful")
        end
    end
end
