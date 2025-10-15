# frozen_string_literal: true

# Schema
#
# Columns
# id: integer (PK)
# paid_amount: float - default: 0.0
# due_amount: float - default: 0.0
# is_settled: boolean - default: false
# expense_id: integer (FK) - not null
# user_id: integer (FK) - not null
# created_at: datetime - not null
# updated_at: datetime - not null
#
# Indexes
# index_split_expenses_on_expense_id (expense_id)
# index_split_expenses_on_user_id (user_id)
class SplitExpense < ApplicationRecord
  belongs_to :expense

  validate :split_expense_due_amount
  validate :split_expense_paid_amount

  private

  def split_expense_due_amount
    return if SplitExpense.where(expense: expense).sum(:due_amount) + attributes['due_amount'] <= expense.paid_amount

    errors.add(:due_amount, 'for splits is more than the paid amount')
  end

  def split_expense_paid_amount
    return if SplitExpense.where(expense: expense).sum(:paid_amount) + attributes['paid_amount'] <= expense.paid_amount

    errors.add(:paid_amount, 'for splits is more than the paid amount')
  end
end
