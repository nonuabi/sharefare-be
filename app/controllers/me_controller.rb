class MeController < ApplicationController
  def show
    render json: {
      status: { code: 200, message: "OK" },
      data: user_payload(current_user)
    }, status: :ok
  end


  private

  def user_payload(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      created_at: user.created_at&.iso8601
    }
  end
end
