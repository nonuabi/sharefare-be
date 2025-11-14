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
      balance = object.balance_for_user(user)
      {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          avatar_url: user.avatar_url_or_generate
        },
        balance: balance,
        owes_you: balance > 0 ? balance : 0,
        you_owe: balance < 0 ? balance.abs : 0
      }
    end
  end

  def recent_expenses
    expenses = object.expenses.includes(:payer, :creator, :split_expenses)
                     .order(created_at: :desc)
                     .limit(10)
    
    expenses.map do |expense|
      {
        id: expense.id,
        description: expense.description,
        amount: expense.paid_amount,
        paid_by: {
          id: expense.payer.id,
          name: expense.payer.name,
          email: expense.payer.email,
          avatar_url: expense.payer.avatar_url_or_generate
        },
        created_at: expense.created_at,
        notes: expense.notes,
        split_count: expense.split_expenses.count
      }
    end
  end
end
