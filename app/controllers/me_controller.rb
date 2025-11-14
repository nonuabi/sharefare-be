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
