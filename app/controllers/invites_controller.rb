# frozen_string_literal: true

class InvitesController < ApplicationController
  before_action :check_logged_in_user

  # GET /api/invites/personal
  # Generate a personal invite code for the user
  def personal
    # Generate a simple invite code based on user ID (can be enhanced)
    invite_code = "CB#{current_user.id.to_s.rjust(6, '0')}#{SecureRandom.hex(4).upcase}"
    
    invite_url = "chopbill://signup?ref=#{invite_code}"
    
    render json: {
      invite_code: invite_code,
      invite_url: invite_url,
      message: 'Share this link with your friends to invite them to ChopBill!'
    }, status: :ok
  end

  # POST /api/groups/:group_id/invites
  # Create a group invite
  def create
    group = Group.find_by(id: params[:group_id])
    return render json: { error: 'Group not found' }, status: :not_found unless group
    
    # Check if user is a member of the group
    unless group.users.include?(current_user)
      return render json: { error: 'You are not a member of this group' }, status: :forbidden
    end

    # Check if there's an existing active invite
    existing_invite = group.group_invites.active.first
    if existing_invite
      return render json: {
        invite: invite_json(existing_invite),
        message: 'Using existing invite link'
      }, status: :ok
    end

    invite = group.group_invites.create!(inviter: current_user)
    
    render json: {
      invite: invite_json(invite),
      message: 'Group invite created successfully'
    }, status: :created
  rescue StandardError => e
    Rails.logger.error "Error creating invite: #{e.full_message}"
    render json: { error: 'Failed to create invite', message: e.message }, status: :bad_request
  end

  # GET /api/invites/:token
  # Get invite details (for validation before signup)
  def show
    invite = GroupInvite.find_by(token: params[:token])
    
    if invite.nil?
      return render json: { error: 'Invalid invite token' }, status: :not_found
    end

    if invite.expired?
      return render json: { error: 'This invite has expired' }, status: :gone
    end

    if invite.used?
      return render json: { error: 'This invite has already been used' }, status: :gone
    end

    render json: {
      invite: invite_json(invite),
      group: {
        id: invite.group.id,
        name: invite.group.name,
        description: invite.group.description
      },
      inviter: {
        id: invite.inviter.id,
        name: invite.inviter.name
      }
    }, status: :ok
  end

  # POST /api/invites/:token/accept
  # Accept a group invite (adds current user to the group)
  def accept
    invite = GroupInvite.find_by(token: params[:token])
    
    if invite.nil?
      return render json: { error: 'Invalid invite token' }, status: :not_found
    end

    unless invite.can_be_used?
      return render json: { error: 'This invite cannot be used' }, status: :gone
    end

    # Check if user is already a member
    if invite.group.users.include?(current_user)
      invite.use!(current_user) # Mark as used even though user was already a member
      return render json: {
        message: 'You are already a member of this group',
        group: {
          id: invite.group.id,
          name: invite.group.name
        }
      }, status: :ok
    end

    # Add user to group
    invite.group.group_members.create!(user_id: current_user.id)
    invite.use!(current_user)

    render json: {
      message: 'Successfully joined the group!',
      group: {
        id: invite.group.id,
        name: invite.group.name
      }
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Error accepting invite: #{e.full_message}"
    render json: { error: 'Failed to accept invite', message: e.message }, status: :bad_request
  end

  private

  def check_logged_in_user
    render json: { error: 'User not logged in' }, status: :unauthorized unless current_user
  end

  def invite_json(invite)
    {
      id: invite.id,
      token: invite.token,
      invite_url: invite.invite_url,
      expires_at: invite.expires_at,
      used: invite.used,
      created_at: invite.created_at
    }
  end
end

