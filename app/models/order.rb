class Order < ApplicationRecord
    has_many :pending_order_payments

    # Suggestion per: https://stackoverflow.com/a/9547179
    # Use these methods with dot notation on object.payments to filter by status:
    has_many :payments, through: :pending_order_payments do
        def successful
            where("pending_order_payments.status = ?", "Successful")
        end

        def pending
            where("pending_order_payments.status = ?", "Pending")
        end

        def failed
            where("pending_order_payments.status = ?", "Failed")
        end
    end

    def balance_due
        balance = self.total

        if !self.payments.successful.empty?
            self.payments.successful.each do |payment|
            balance -= payment.amount
            end
        end

        if balance < 0
            balance = 0
        end

        return balance
    end
    
end
