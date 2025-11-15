# frozen_string_literal: true

class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :description,
             :total_expense,
             :balance_for_me,
             :member_count,
             :members,
             :member_balances,
             :recent_expenses,
             :created_at, :updated_at

  def members
    object.users.map do |user|
      {
        id: user.id,
        name: user.name,
        email: user.email,
        phone_number: user.phone_number,
        avatar_url: user.avatar_url_or_generate
      }
    end
  end

  def total_expense
    object.total_expense
  end

  def balance_for_me
    return 0 unless instance_options[:current_user]
    object.balance_for_user(instance_options[:current_user])
  end

  def member_count
    object.users.count
  end

  def member_balances
    return [] unless instance_options[:current_user]
    current_user = instance_options[:current_user]
    
    object.users.map do |user|
      # Calculate pairwise balance between current_user and this user
      # This is: (what user owes current_user) - (what current_user owes user)
      
      # What user owes current_user: user's share in expenses where current_user paid
      amount_they_owe_me = object.split_expenses
        .joins(:expense)
        .where(expenses: { payer_id: current_user.id })
        .where(user_id: user.id)
        .sum(:due_amount)
      
      # What current_user owes user: current_user's share in expenses where user paid
      amount_i_owe_them = object.split_expenses
        .joins(:expense)
        .where(expenses: { payer_id: user.id })
        .where(user_id: current_user.id)
        .sum(:due_amount)
      
      # Net balance from current_user's perspective
      balance = amount_they_owe_me - amount_i_owe_them
      
      {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          phone_number: user.phone_number,
          avatar_url: user.avatar_url_or_generate
        },
        balance: balance,
        owes_you: balance > 0 ? balance : 0,
        you_owe: balance < 0 ? balance.abs : 0
      }
    end
  end

  def recent_expenses
    # Return all expenses, ordered by most recent first
    # The frontend can limit the display as needed
    expenses = object.expenses.includes(:payer, :creator, :split_expenses)
                     .order(created_at: :desc)
    
    expenses.map do |expense|
      {
        id: expense.id,
        description: expense.description,
        amount: expense.paid_amount,
        paid_by: {
          id: expense.payer.id,
          name: expense.payer.name,
          email: expense.payer.email,
          phone_number: expense.payer.phone_number,
          avatar_url: expense.payer.avatar_url_or_generate
        },
        created_at: expense.created_at,
        notes: expense.notes,
        split_count: expense.split_expenses.count
      }
    end
  end
end
