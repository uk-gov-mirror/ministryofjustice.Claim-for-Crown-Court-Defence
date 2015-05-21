class Expense < ActiveRecord::Base
  belongs_to :expense_type
  belongs_to :claim

  validates :expense_type, presence: true
  validates :claim, presence: true
  validates :quantity, :rate, :hours, :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  after_save do
    claim.update_expenses_total
    claim.update_total
  end

  after_destroy do
    claim.update_expenses_total
    claim.update_total
  end
end
