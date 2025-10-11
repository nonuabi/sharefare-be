class UsersController < ApplicationController
  # TODO: Implement pagination
  def index
    users = User.all
    render json: { users: users.map { |user| prepare_user(user) } }, status: :ok
  end

  private

  def prepare_user(user)
    user.as_json(only: %i[id email name])
  end
end
