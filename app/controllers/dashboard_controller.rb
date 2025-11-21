# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    Rails.logger.info { "Dashboard request started for user #{current_user.id}" }
    
    # Eager load associations to avoid N+1 queries
    user_groups = current_user.groups.includes(
      :users, 
      :settlements,
      expenses: :split_expenses,
      split_expenses: :expense
    )
    
    Rails.logger.info { "Found #{user_groups.count} groups for user #{current_user.id}" }
    
    # Calculate totals across all groups
    total_owed_to_me = 0.0
    total_i_owe = 0.0
    outstanding_balances_hash = {}
    
    user_groups.each do |group|
      begin
        balance = group.balance_for_user(current_user)
        if balance > 0
          total_owed_to_me += balance
        elsif balance < 0
          total_i_owe += balance.abs
        end
      rescue => e
        Rails.logger.error { "Error calculating balance for group #{group.id}: #{e.message}" }
        next
      end
      
      # Calculate balances with each member in this group
      group_users = group.users.where.not(id: current_user.id).to_a
      next if group_users.empty?
      
      group_users.each do |other_user|
        begin
          # Calculate net balance between current_user and other_user
          # This is: (what other_user owes me) - (what I owe other_user)
          
          # What other_user owes me: their share in expenses where I paid
          amount_they_owe_me = group.split_expenses
            .joins(:expense)
            .where(expenses: { payer_id: current_user.id })
            .where(user_id: other_user.id)
            .sum(:due_amount)
          
          # What I owe other_user: my share in expenses where they paid
          # Handle both old format (due_amount = 0, share in paid_amount) and new format
          amount_i_owe_them = group.split_expenses
            .joins(:expense)
            .where(expenses: { payer_id: other_user.id })
            .where(user_id: current_user.id)
            .sum("COALESCE(NULLIF(split_expenses.due_amount, 0), split_expenses.paid_amount)")
          
          # Account for settlements between these two users
          # Settlements where current_user paid other_user (reduces what current_user owes other_user)
          settlements_i_paid = group.settlements
            .where(payer_id: current_user.id, payee_id: other_user.id)
            .sum(:amount)
          
          # Settlements where other_user paid current_user (reduces what other_user owes current_user)
          settlements_they_paid = group.settlements
            .where(payer_id: other_user.id, payee_id: current_user.id)
            .sum(:amount)
          
          # Net amount calculation:
          # Base net = what they owe me - what I owe them
          # Add settlements where I paid (reduces what I owe, increases net)
          # Subtract settlements where they paid (reduces what they owe, decreases net)
          net_amount = (amount_they_owe_me - amount_i_owe_them) + settlements_i_paid - settlements_they_paid
        rescue => e
          Rails.logger.error { "Error calculating balance with user #{other_user.id}: #{e.message}" }
          next
        end
        
        if net_amount.abs > 0.01 # Only include if significant
          if outstanding_balances_hash[other_user.id]
            outstanding_balances_hash[other_user.id][:amount] += net_amount
            # Update direction based on final amount
            if outstanding_balances_hash[other_user.id][:amount] > 0
              outstanding_balances_hash[other_user.id][:direction] = '+'
            else
              outstanding_balances_hash[other_user.id][:direction] = '-'
            end
            # Initialize groups array if not present (for backward compatibility)
            outstanding_balances_hash[other_user.id][:groups] ||= []
            # Add group to groups list if not already present
            unless outstanding_balances_hash[other_user.id][:groups].any? { |g| g[:id] == group.id }
              outstanding_balances_hash[other_user.id][:groups] << {
                id: group.id,
                name: group.name
              }
            end
          else
              outstanding_balances_hash[other_user.id] = {
                user: {
                  id: other_user.id,
                  name: other_user.name,
                  email: other_user.email,
                  phone_number: other_user.phone_number,
                  avatar_url: other_user.avatar_url_or_generate
                },
              amount: net_amount,
              direction: net_amount > 0 ? '+' : '-',
              groups: [{
                id: group.id,
                name: group.name
              }]
            }
          end
        end
      end
    end
    
    # Convert hash to array, filter zero balances, format, and sort by most recent activity
    outstanding_balances = outstanding_balances_hash.values
      .select { |b| b[:amount].abs > 0.01 }
      .map { |b| 
        # Find the most recent expense date across all groups for this balance
        group_ids = (b[:groups] || []).map { |g| g[:id] }
        most_recent_expense_date = if group_ids.any?
          Expense.joins(:group)
            .where(group_id: group_ids)
            .where('expenses.payer_id = ? OR expenses.id IN (SELECT expense_id FROM split_expenses WHERE user_id = ?)', 
                   current_user.id, current_user.id)
            .maximum(:created_at)
        else
          nil
        end
        
        {
          user: b[:user],
          amount: b[:amount].abs.round(2),
          direction: b[:amount] > 0 ? '+' : '-',
          groups: b[:groups] || [],
          _most_recent_date: most_recent_expense_date || Time.at(0) # Use epoch if no expenses
        }
      }
      .sort_by { |b| -(b[:_most_recent_date] || Time.at(0)).to_f } # Sort descending (most recent first)
      .map { |b| 
        {
          user: b[:user],
          amount: b[:amount],
          direction: b[:direction],
          groups: b[:groups]
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
                  phone_number: expense.payer.phone_number,
                  avatar_url: expense.payer.avatar_url_or_generate
                },
          group: {
            id: expense.group.id,
            name: expense.group.name
          },
          created_at: expense.created_at
        }
      end
    
    Rails.logger.info { "Dashboard calculation completed for user #{current_user.id}" }
    
    render json: {
      total_owed_to_me: total_owed_to_me.round(2),
      total_i_owe: total_i_owe.round(2),
      outstanding_balances: outstanding_balances,
      recent_expenses: recent_expenses
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error { "Dashboard error: #{e.full_message}" }
    Rails.logger.error { e.backtrace.first(10).join("\n") }
    render json: { error: 'Error fetching dashboard data', message: e.message }, status: :unprocessable_entity
  end
end
