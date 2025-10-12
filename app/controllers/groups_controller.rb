class GroupsController < ApplicationController
  before_action :check_logged_in_user

  def create
    group = Group.new(group_base_params)
    group.owner = current_user

    if group.save
      members = members_params
      if members.present?
        members.each do |member|
          is_new = ActiveModel::Type::Boolean.new.cast(member[:newUser])
          if is_new
            temp_password = 'Temp@1234'
            user = User.create!(email: member[:email], password: temp_password, password_confirmation: temp_password,
                                name: "Invited By #{current_user.name}")
            group.group_members.create!(user_id: user.id)
          else
            user = User.find_by(id: member[:id], email: member[:email])
            next unless user

            group.group_members.create!(user_id: user.id) unless group.users.include?(user)
          end
        end
      end

      render json: { message: 'Group created successfully', group: }, status: :ok
    else
      render json: { error: 'Error creating group', message: group.errors.full_messages }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.info { "Group not able to be created: #{e.full_message}" }
    group.destroy if group&.persisted?
    render json: { error: 'Error creating group', message: e.full_message }, status: :bad_request
  end

  def update
    group = find_user
    return render json: { error: 'Invalid group' }, status: :not_found unless group

    if group.update(group_base_params)
      return render json: { message: 'Group updated successfully', group: },
                    status: :ok
    end

    render json: { error: 'Group not updated' }, status: :bad_request
  end

  def index
    groups = Group.joins(:group_members).where('groups.owner_id = ? OR group_members.user_id = ?',
                                               current_user.id, current_user.id).distinct
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

  def group_base_params
    params.permit(:name, :description)
  end

  def members_params
    permitted = params.permit(members: %i[email id name newUser])
    permitted[:members]
  end

  def find_user
    Group.includes(:users).find_by(id: params[:id])
  end
end
