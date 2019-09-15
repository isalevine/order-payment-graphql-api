class Payment < ApplicationRecord
    has_many :pending_order_payments
    has_many :orders, through: :pending_order_payments   
end
