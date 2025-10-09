class GroupsController < ApplicationController
  before_action :check_logged_in_user

  def create
    group = Group.new(group_params)
    group.owner = current_user

    if group.save! && group_params[:member_ids].present?
      group_params[:member_ids].each do |member_id|
        group.group_members.create!(user_id: member_id)
      end
    end

    render json: { message: 'Group created successfully', group: }, status: :ok
  rescue StandardError => e
    rails.logger.info { "Group not able to created: #{e.full_message}" }
    group.destroy
    render json: { error: 'Error creating group', message: e.full_message }, status: :bad_request
  end

  def update
    group = find_user
    return render json: { error: 'Invalid group' }, status: :not_found unless group

    return render json: { message: 'Group updated successfully', group: }, status: :ok if group.update(group_params)

    render json: { error: 'Group not updated' }, status: :bad_request
  end

  def index
    groups = Group.where(owner_id: current_user.id)
    render json: { groups: }, status: :ok
  end

  def show
    group = find_user
    return render json: { error: 'Invalid group' }, status: :not_found unless group

    render json: { group:, group_members: group.users }, status: :ok
  end

  private

  def check_logged_in_user
    render json: { error: 'User not logged in' }, status: :not_found unless current_user
  end

  def group_params
    params.require(:group).permit(:name, :description, :member_ids)
  end

  def find_user
    Group.includes(:users).find_by(id: params[:id])
  end
end
