class MeController < ApplicationController
  def show
    render json: {
      data: user_payload(current_user)
    }, status: :ok
  end

  def update
    if current_user.update(profile_params)
      render json: user_payload(current_user), status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Prevent deletion if user owns groups
    if current_user.owned_groups.any?
      return render json: {
        error: 'Cannot delete account',
        message: 'You cannot delete your account while you own groups. Please transfer ownership or delete your groups first.'
      }, status: :unprocessable_entity
    end

    # Check if user has expenses (as payer or creator)
    # This is a soft check - we'll let the database handle the constraint
    # but provide a helpful message if deletion fails
    has_expenses = current_user.expenses.exists? || 
                   Expense.where(payer_id: current_user.id).exists? ||
                   Expense.where(creator_id: current_user.id).exists?

    if has_expenses
      return render json: {
        error: 'Cannot delete account',
        message: 'You cannot delete your account because you have expenses associated with it. Please contact support for assistance.'
      }, status: :unprocessable_entity
    end

    # Remove user from all groups they're a member of
    current_user.group_members.destroy_all

    # Delete group invites created by this user
    current_user.group_invites.destroy_all

    # Delete the user account
    # This will cascade through other associations
    user_id = current_user.id
    current_user.destroy

    render json: {
      message: 'Account deleted successfully'
    }, status: :ok
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: {
      error: 'Cannot delete account',
      message: 'Unable to delete account. You may have expenses or settlements associated with your account. Please contact support if this issue persists.'
    }, status: :unprocessable_entity
  rescue ActiveRecord::InvalidForeignKey => e
    Rails.logger.error "Foreign key constraint violation while deleting user: #{e.message}"
    render json: {
      error: 'Cannot delete account',
      message: 'Unable to delete account due to associated data. Please contact support for assistance.'
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error deleting user account: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      error: 'Cannot delete account',
      message: 'An error occurred while deleting your account. Please try again later.'
    }, status: :internal_server_error
  end

  private

  def user_payload(user)
    {
      id: user.id,
      email: user.email,
      phone_number: user.phone_number,
      name: user.name,
      avatar_url: user.avatar_url_or_generate,
      created_at: user.created_at&.iso8601,
      stats: {
        total_groups: user.groups.count,
        owned_groups: user.owned_groups.count,
        total_expenses: Expense.where(creator_id: user.id).count,
        total_spent: Expense.where(creator_id: user.id).sum(:paid_amount).round(2)
      }
    }
  end

  def profile_params
    params.permit(:name, :email, :phone_number)
  end
end
