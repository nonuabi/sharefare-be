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
          is_new = ActiveModel::Type::Boolean.new.cast(member[:newUser])
          if is_new
            temp_password = 'Temp@1234'
            user = User.create!(email: member[:email], password: temp_password, password_confirmation: temp_password,
                                name: "(New) #{member[:email]}")
            group.group_members.create!(user_id: user.id)
          else
            user = User.find_by(id: member[:id], email: member[:email])
            next unless user

            group.group_members.create!(user_id: user.id) unless group.users.include?(user)
          end
        end
      end

      render json: { message: 'Group created successfully', group: group, group_members: group.users }, status: :ok
    else
      render json: { error: 'Error creating group', message: group.messages }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.info { "Group not able to be created: #{e.full_message}" }
    group.destroy if group&.persisted?
    render json: { error: 'Error creating group', message: e.message }, status: :bad_request
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
    groups = Group.joins(:group_members).where('groups.owner_id = ? OR group_members.user_id = ?',
                                               current_user.id, current_user.id).distinct.order(created_at: :desc)
    render json: { groups: groups.map { |group| group_json(group) } }, status: :ok
  end

  def show
    return render json: { error: 'Invalid group' }, status: :not_found unless @group

    render json: { group: @group, group_members: @group.users }, status: :ok
  end

  private

  def check_logged_in_user
    render json: { error: 'User not logged in' }, status: :not_found unless current_user
  end

  def group_base_params
    params.require(:group).permit(:name, :description)
  end

  def members_params
    permitted = params.require(:group).permit(members: %i[email id name newUser])
    permitted[:members]
  end

  def find_group
    @group = Group.includes(:users).find_by(id: params[:id] || params[:group_id])
    return if @group

    render json: { error: 'Group not found!' }, status: :not_found
  end

  def group_json(group)
    group.as_json(only: %i[id name description owner_id created_at updated_at]).merge(
      member_count: group.users&.count || 0
    )
  end
end
