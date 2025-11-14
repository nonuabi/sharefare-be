# frozen_string_literal: true

class Group < ApplicationRecord
  has_paper_trail

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :group_members
  has_many :users, through: :group_members

  has_many :expenses
  has_many :split_expenses, through: :expenses

  # total expense in a group
  def total_expense
    expenses.sum(:paid_amount)
  end

  # balance for a user in the group
  # Positive balance = user is owed money (they paid more than their share)
  # Negative balance = user owes money (they paid less than their share)
  def balance_for_user(user)
    return 0 unless users.include?(user)

    total_paid = expenses.where(payer_id: user.id).sum(:paid_amount)
    total_owed = split_expenses
                  .where(user_id: user.id)
                  .sum(:due_amount)
    total_paid - total_owed
  end
end
