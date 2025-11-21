# frozen_string_literal: true

class SettlementsController < ApplicationController
  before_action :check_logged_in_user
  before_action :find_group
  before_action :check_group_membership

  # GET /api/groups/:group_id/settlements
  def index
    settlements = @group.settlements
      .includes(:payer, :payee, :settled_by)
      .order(created_at: :desc)
    
    render json: {
      settlements: settlements.map { |s| settlement_json(s) }
    }, status: :ok
  end

  # POST /api/groups/:group_id/settlements
  def create
    payer_id = params[:settlement][:payer_id]&.to_i
    payee_id = params[:settlement][:payee_id]&.to_i
    amount = params[:settlement][:amount]&.to_f
    notes = params[:settlement][:notes]

    # Validate required fields
    unless payer_id && payee_id && amount && amount > 0
      return render json: {
        error: 'Invalid settlement',
        message: 'Please provide payer_id, payee_id, and a positive amount.'
      }, status: :bad_request
    end

    # Find users
    payer = User.find_by(id: payer_id)
    payee = User.find_by(id: payee_id)

    unless payer && payee
      return render json: {
        error: 'Invalid users',
        message: 'Payer or payee not found.'
      }, status: :not_found
    end

    # Ensure both users are group members
    unless @group.users.include?(payer) && @group.users.include?(payee)
      return render json: {
        error: 'Invalid users',
        message: 'Both payer and payee must be members of this group.'
      }, status: :bad_request
    end

    # Ensure payer and payee are different
    if payer_id == payee_id
      return render json: {
        error: 'Invalid settlement',
        message: 'Payer and payee must be different users.'
      }, status: :bad_request
    end

    # Check if current user is involved in the settlement
    unless payer_id == current_user.id || payee_id == current_user.id
      return render json: {
        error: 'Unauthorized',
        message: 'You can only create settlements involving yourself.'
      }, status: :forbidden
    end

    # Calculate current balance between users
    payer_balance = @group.balance_for_user(payer)
    payee_balance = @group.balance_for_user(payee)

    # Validate settlement makes sense
    # If payer owes payee, payer_balance should be negative and payee_balance positive
    # The settlement amount should not exceed the debt
    if payer_id == current_user.id
      # Current user is paying someone
      # Their balance should be negative (they owe)
      if payer_balance >= 0
        return render json: {
          error: 'Invalid settlement',
          message: 'You do not owe this person. Your balance is positive or zero.'
        }, status: :bad_request
      end
      # Settlement amount should not exceed what they owe
      if amount > payer_balance.abs
        return render json: {
          error: 'Invalid settlement',
          message: "Settlement amount (₹#{amount}) exceeds what you owe (₹#{payer_balance.abs.round(2)})."
        }, status: :bad_request
      end
    else
      # Current user is receiving payment
      # Their balance should be positive (they are owed)
      if payee_balance <= 0
        return render json: {
          error: 'Invalid settlement',
          message: 'This person does not owe you. Your balance is negative or zero.'
        }, status: :bad_request
      end
      # Settlement amount should not exceed what they are owed
      if amount > payee_balance
        return render json: {
          error: 'Invalid settlement',
          message: "Settlement amount (₹#{amount}) exceeds what you are owed (₹#{payee_balance.round(2)})."
        }, status: :bad_request
      end
    end

    # Create settlement
    settlement = @group.settlements.build(
      payer: payer,
      payee: payee,
      amount: amount,
      settled_by: current_user,
      notes: notes
    )

    if settlement.save
      render json: {
        message: 'Settlement created successfully',
        settlement: settlement_json(settlement)
      }, status: :created
    else
      render json: {
        error: 'Could not create settlement',
        message: settlement.errors.full_messages.to_sentence
      }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Error creating settlement: #{e.full_message}"
    render json: {
      error: 'Could not create settlement',
      message: 'Something went wrong. Please try again.'
    }, status: :internal_server_error
  end

  # GET /api/groups/:group_id/settlements/:id
  def show
    settlement = @group.settlements.find_by(id: params[:id])
    
    unless settlement
      return render json: {
        error: 'Settlement not found'
      }, status: :not_found
    end

    render json: {
      settlement: settlement_json(settlement)
    }, status: :ok
  end

  private

  def check_logged_in_user
    render json: { error: 'User not logged in' }, status: :unauthorized unless current_user
  end

  def find_group
    @group = Group.find_by(id: params[:group_id])
    return if @group

    render json: { error: 'Group not found' }, status: :not_found
  end

  def check_group_membership
    return if @group&.users&.include?(current_user)

    render json: { error: 'You are not a member of this group' }, status: :forbidden
  end

  def settlement_json(settlement)
    {
      id: settlement.id,
      group_id: settlement.group_id,
      payer: {
        id: settlement.payer.id,
        name: settlement.payer.name,
        email: settlement.payer.email,
        phone_number: settlement.payer.phone_number,
        avatar_url: settlement.payer.avatar_url_or_generate
      },
      payee: {
        id: settlement.payee.id,
        name: settlement.payee.name,
        email: settlement.payee.email,
        phone_number: settlement.payee.phone_number,
        avatar_url: settlement.payee.avatar_url_or_generate
      },
      amount: settlement.amount.to_f,
      notes: settlement.notes,
      settled_by: {
        id: settlement.settled_by.id,
        name: settlement.settled_by.name
      },
      created_at: settlement.created_at.iso8601,
      updated_at: settlement.updated_at.iso8601
    }
  end
end


