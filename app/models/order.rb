class Order < ApplicationRecord
    has_many :pending_order_payments
    has_many :payments, through: :pending_order_payments
end
