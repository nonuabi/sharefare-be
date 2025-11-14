# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    user_groups = current_user.groups.includes(:users, :expenses, :split_expenses)
    
    # Calculate totals across all groups
    total_owed_to_me = 0.0
    total_i_owe = 0.0
    outstanding_balances_hash = {}
    
    user_groups.each do |group|
      balance = group.balance_for_user(current_user)
      if balance > 0
        total_owed_to_me += balance
      elsif balance < 0
        total_i_owe += balance.abs
      end
      
      # Calculate balances with each member in this group
      group.users.where.not(id: current_user.id).each do |other_user|
        # For each expense in this group, calculate net balance with this user
        amount_they_owe_me = 0.0
        amount_i_owe_them = 0.0
        
        group.expenses.includes(:split_expenses).each do |expense|
          my_split = expense.split_expenses.find_by(user_id: current_user.id)
          their_split = expense.split_expenses.find_by(user_id: other_user.id)
          
          next unless my_split && their_split
          
          if expense.payer_id == current_user.id
            # I paid, they owe me their share
            amount_they_owe_me += their_split.due_amount
          elsif expense.payer_id == other_user.id
            # They paid, I owe them my share
            amount_i_owe_them += my_split.due_amount
          end
        end
        
        net_amount = amount_they_owe_me - amount_i_owe_them
        
        if net_amount.abs > 0.01 # Only include if significant
          if outstanding_balances_hash[other_user.id]
            outstanding_balances_hash[other_user.id][:amount] += net_amount
            # Update direction based on final amount
            if outstanding_balances_hash[other_user.id][:amount] > 0
              outstanding_balances_hash[other_user.id][:direction] = '+'
            else
              outstanding_balances_hash[other_user.id][:direction] = '-'
            end
          else
              outstanding_balances_hash[other_user.id] = {
                user: {
                  id: other_user.id,
                  name: other_user.name,
                  email: other_user.email,
                  avatar_url: other_user.avatar_url_or_generate
                },
              amount: net_amount,
              direction: net_amount > 0 ? '+' : '-'
            }
          end
        end
      end
    end
    
    # Convert hash to array, filter zero balances, and format
    outstanding_balances = outstanding_balances_hash.values
      .select { |b| b[:amount].abs > 0.01 }
      .map { |b| 
        {
          user: b[:user],
          amount: b[:amount].abs.round(2),
          direction: b[:amount] > 0 ? '+' : '-'
        }
      }
    
    # Get recent expenses across all groups (last 10)
    recent_expenses = Expense
      .joins(:group)
      .joins('INNER JOIN group_members ON groups.id = group_members.group_id')
      .where('group_members.user_id = ?', current_user.id)
      .includes(:payer, :group)
      .order(created_at: :desc)
      .limit(10)
      .map do |expense|
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
          group: {
            id: expense.group.id,
            name: expense.group.name
          },
          created_at: expense.created_at
        }
      end
    
    render json: {
      total_owed_to_me: total_owed_to_me.round(2),
      total_i_owe: total_i_owe.round(2),
      outstanding_balances: outstanding_balances,
      recent_expenses: recent_expenses
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error { "Dashboard error: #{e.full_message}" }
    render json: { error: 'Error fetching dashboard data', message: e.message }, status: :unprocessable_entity
  end
end
