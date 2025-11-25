# frozen_string_literal: true

class Group < ApplicationRecord
  has_paper_trail

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :group_members, dependent: :destroy
  has_many :users, through: :group_members
  has_many :group_invites, dependent: :destroy

  has_many :expenses, dependent: :destroy
  has_many :split_expenses, through: :expenses, dependent: :destroy
  has_many :settlements, dependent: :destroy

  # total expense in a group
  def total_expense
    expenses.sum(:paid_amount)
  end

  # balance for a user in the group
  # Positive balance = user is owed money (they paid more than their share)
  # Negative balance = user owes money (they paid less than their share)
  # Accounts for settlements: settlements reduce the balance
  def balance_for_user(user)
    return 0 unless users.include?(user)

    total_paid = 0.0
    total_owed = 0.0
    
    # Get all split_expenses for this user in one query (more efficient)
    user_splits = split_expenses.where(user_id: user.id).includes(:expense)
    
    user_splits.each do |my_split|
      expense = my_split.expense
      
      # Check if this is old format (due_amount = 0 for payer) or new format (due_amount > 0 for payer)
      is_old_format = (expense.payer_id == user.id && my_split.due_amount == 0)
      
      if expense.payer_id == user.id
        # User paid this expense
        if is_old_format
          # Old format: paid_amount in split_expense is the split amount, need to use expense.paid_amount
          total_paid += expense.paid_amount
        else
          # New format: paid_amount in split_expense is the full amount
          total_paid += my_split.paid_amount
        end
      end
      
      # What user owes (their share)
      if is_old_format
        # Old format: payer's share is stored in paid_amount, not due_amount
        total_owed += my_split.paid_amount
      else
        # New format: share is stored in due_amount
        total_owed += my_split.due_amount
      end
    end
    
    # Calculate base balance = what they paid - what they owe
    base_balance = total_paid - total_owed
    
    # Account for settlements
    # Balance = what you paid - what you owe
    # Positive balance = you're owed money
    # Negative balance = you owe money
    settlements_as_payer = settlements.where(payer_id: user.id).sum(:amount)
    settlements_as_payee = settlements.where(payee_id: user.id).sum(:amount)
    
    # Settlement logic:
    # - If user paid someone (settlement as payer): reduces what they owe → balance INCREASES (becomes less negative)
    #   Example: balance = -₹100, pay ₹50 → new balance = -₹50 (add settlement)
    # - If user received payment (settlement as payee): reduces what they're owed → balance DECREASES (becomes less positive)
    #   Example: balance = +₹100, receive ₹50 → new balance = +₹50 (subtract settlement)
    base_balance + settlements_as_payer - settlements_as_payee
  end
end
