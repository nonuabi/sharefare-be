class UsersController < ApplicationController
  # TODO: Implement pagination
  def index
    users = User.all
    render json: { users: }, status: :ok
  end
end
