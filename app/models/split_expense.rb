# frozen_string_literal: true

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
