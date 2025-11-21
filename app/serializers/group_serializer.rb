# frozen_string_literal: true

class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :description,
             :total_expense,
             :balance_for_me,
             :member_count,
             :members,
             :member_balances,
             :recent_expenses,
             :recent_settlements,
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
        .sum("COALESCE(NULLIF(split_expenses.due_amount, 0), split_expenses.paid_amount)")
      
      # Account for settlements between these two users
      settlements_i_paid = object.settlements
        .where(payer_id: current_user.id, payee_id: user.id)
        .sum(:amount)
      
      settlements_they_paid = object.settlements
        .where(payer_id: user.id, payee_id: current_user.id)
        .sum(:amount)
      
      # Net balance from current_user's perspective (accounting for settlements)
      balance = (amount_they_owe_me - amount_i_owe_them) + settlements_i_paid - settlements_they_paid
      
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

  def recent_settlements
    # Return all settlements, ordered by most recent first
    settlements = object.settlements
      .includes(:payer, :payee, :settled_by)
      .order(created_at: :desc)
    
    settlements.map do |settlement|
      {
        id: settlement.id,
        payer: {
          id: settlement.payer.id,
          name: settlement.payer.name,
          email: settlement.payer.email,
          phone_number: settlement.payer.phone_number,
          avatar_url: settlement.payer.avatar_url_or_generate
        },
        payee: {
          id: settlement.payee.id,
          name: settlement.payee.name,
          email: settlement.payee.email,
          phone_number: settlement.payee.phone_number,
          avatar_url: settlement.payee.avatar_url_or_generate
        },
        amount: settlement.amount.to_f,
        notes: settlement.notes,
        settled_by: {
          id: settlement.settled_by.id,
          name: settlement.settled_by.name
        },
        created_at: settlement.created_at.iso8601
      }
    end
  end
end
