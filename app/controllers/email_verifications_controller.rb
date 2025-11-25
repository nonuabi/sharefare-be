class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:send_code, :verify_code]
  respond_to :json

  # POST /api/email_verifications/send_code
  # For authenticated users: sends code to their email
  # For unauthenticated users: requires email in params
  def send_code
    user = find_user_for_verification

    unless user
      return render json: {
        error: 'User not found',
        message: 'Please provide a valid email address or sign in.'
      }, status: :not_found
    end

    unless user.email.present?
      return render json: {
        error: 'No email address',
        message: 'This account does not have an email address associated with it.'
      }, status: :unprocessable_entity
    end

    unless user.can_resend_verification_code?
      time_remaining = (60 - (Time.current - user.email_verification_code_sent_at).to_i).seconds
      return render json: {
        error: 'Too many requests',
        message: "Please wait #{time_remaining.to_i} seconds before requesting another code."
      }, status: :too_many_requests
    end

    code = user.generate_verification_code
    
    begin
      EmailVerificationMailer.verification_code_email(user, code).deliver_now
      
      render json: {
        status: { code: 200, message: 'Verification code sent successfully.' },
        data: {
          email: user.email,
          expires_in: User::VERIFICATION_CODE_EXPIRY.to_i
        }
      }, status: :ok
    rescue => e
      Rails.logger.error "Failed to send verification email: #{e.message}"
      render json: {
        error: 'Failed to send email',
        message: 'We encountered an error sending the verification code. Please try again later.'
      }, status: :internal_server_error
    end
  end

  # POST /api/email_verifications/verify_code
  # Verifies the code for a user
  def verify_code
    user = find_user_for_verification

    unless user
      return render json: {
        error: 'User not found',
        message: 'Please provide a valid email address or sign in.'
      }, status: :not_found
    end

    code = params[:code]

    unless code.present?
      return render json: {
        error: 'Code required',
        message: 'Please provide the verification code.'
      }, status: :unprocessable_entity
    end

    if user.verify_email!(code)
      render json: {
        status: { code: 200, message: 'Email verified successfully.' },
        data: {
          email: user.email,
          email_verified: user.email_verified
        }
      }, status: :ok
    else
      if user.email_verification_code_sent_at.nil?
        error_message = 'No verification code has been sent. Please request a new code.'
      elsif Time.current > user.email_verification_code_sent_at + User::VERIFICATION_CODE_EXPIRY
        error_message = 'Verification code has expired. Please request a new code.'
      else
        error_message = 'Invalid verification code. Please check and try again.'
      end

      render json: {
        error: 'Verification failed',
        message: error_message
      }, status: :unprocessable_entity
    end
  end

  # GET /api/email_verifications/status
  # Returns the verification status for the current user
  def status
    render json: {
      status: { code: 200, message: 'Status retrieved successfully.' },
      data: {
        email: current_user.email,
        email_verified: current_user.email_verified,
        has_pending_code: current_user.email_verification_code.present?,
        code_expires_at: current_user.email_verification_code_sent_at&.+(
          User::VERIFICATION_CODE_EXPIRY
        )
      }
    }, status: :ok
  end

  private

  def find_user_for_verification
    # If user is authenticated, use current_user
    return current_user if current_user.present?

    # Otherwise, try to find by email from params
    email = params[:email]
    return nil unless email.present?

    User.find_by(email: email)
  end
end

