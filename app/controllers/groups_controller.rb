# frozen_string_literal: true

class GroupsController < ApplicationController
  before_action :check_logged_in_user
  before_action :find_group, only: %i[show update]

  def create
    group = Group.new(group_base_params)
    group.owner = current_user
    if group.save!
      group.group_members.create!(user_id: current_user.id)
      members = members_params
      if members.present?
        members.each do |member|
          # Only add existing users - no new user creation
          user = if member[:id].present?
            User.find_by(id: member[:id])
          elsif member[:email].present?
            User.find_by(email: member[:email])
          elsif member[:phone_number].present?
            User.find_by(phone_number: member[:phone_number])
          end
          next unless user

          group.group_members.create!(user_id: user.id) unless group.users.include?(user)
        end
      end

      render json: { message: 'Group created successfully', group: group_json(group), group_members: group.users },
             status: :ok
    else
      error_message = group.errors.full_messages.to_sentence
      render json: { error: 'Could not create group', message: error_message.presence || 'Please check your input and try again.' }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.info { "Group not able to be created: #{e.full_message}" }
    group.destroy if group&.persisted?
    render json: { error: 'Could not create group', message: 'Something went wrong. Please try again later.' }, status: :bad_request
  end

  def update
    return render json: { error: 'Invalid group' }, status: :not_found unless @group

    if @group.update(group_base_params)
      return render json: { message: 'Group updated successfully', group: @group },
                    status: :ok
    end

    render json: { error: 'Group not updated' }, status: :bad_request
  end

  def index
    groups = Group.joins(:group_members)
      .where('groups.owner_id = ? OR group_members.user_id = ?', current_user.id, current_user.id)
      .distinct
      .includes(:users, expenses: [:payer, :split_expenses])
      .order(created_at: :desc)
    render json: { groups: groups.map { |group| group_json(group) } }, status: :ok
  end

  def show
    return render json: { error: 'Invalid group' }, status: :not_found unless @group

    render json: @group, serializer: GroupSerializer, current_user: current_user, status: :ok
  end

  private

  def check_logged_in_user
    render json: { error: 'User not logged in' }, status: :not_found unless current_user
  end

  def group_base_params
    params.require(:group).permit(:name, :description)
  end

  def members_params
    permitted = params.require(:group).permit(members: %i[email phone_number id name])
    permitted[:members]
  end

  def find_group
    @group = Group.includes(:users).find_by(id: params[:id] || params[:group_id])
    return if @group

    render json: { error: 'Group not found!' }, status: :not_found
  end

  def group_json(group)
    # Calculate balance for current user
    balance_for_me = group.balance_for_user(current_user)
    
    # Get total expense amount
    total_expense = group.total_expense
    
    # Get expense count
    expense_count = group.expenses.count
    
    # Get recent expenses (last 3) for summary
    recent_expenses = group.expenses
      .includes(:payer)
      .order(created_at: :desc)
      .limit(3)
    
    # Get last expense date
    last_expense = group.expenses.order(created_at: :desc).first
    last_expense_date = last_expense&.created_at
    
    # Get member avatars (up to 4 for display)
    member_avatars = group.users.limit(4).map do |user|
      {
        id: user.id,
        name: user.name,
        avatar_url: user.avatar_url_or_generate
      }
    end
    
    # Get recent expense summary
    recent_expenses_summary = recent_expenses.map do |expense|
      {
        id: expense.id,
        description: expense.description,
        amount: expense.paid_amount,
        paid_by: {
          id: expense.payer.id,
          name: expense.payer.name,
          avatar_url: expense.payer.avatar_url_or_generate
        },
        created_at: expense.created_at
      }
    end
    
    group.as_json(only: %i[id name description owner_id created_at updated_at]).merge(
      member_count: group.users&.count || 0,
      totalAmount: total_expense,
      balanceForMe: balance_for_me.round(2),
      expense_count: expense_count,
      last_expense_date: last_expense_date,
      member_avatars: member_avatars,
      recent_expenses_summary: recent_expenses_summary
    )
  end
end
