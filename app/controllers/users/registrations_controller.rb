class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  # POST /signup
  def create
    build_resource(sign_up_params)

    if resource.save
      sign_in(resource_name, resource, store: false)

      token, _payload = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil)
      response.set_header("Authorization", "Bearer #{token}")

      user_json = { 
        id: resource.id, 
        email: resource.email, 
        phone_number: resource.phone_number,
        name: resource.name 
      }

      render json: {
        status: { code: 201, message: "Signed up successfully." },
        data: user_json,
        token: token
      }, status: :created
    else
      error_message = resource.errors.full_messages.to_sentence
      render json: {
        error: 'Could not create account',
        message: error_message.presence || 'Please check your information and try again.'
      }, status: :unprocessable_entity
    end
  end

  private

  def sign_up_params
    permitted = params.require(:user).permit(:email, :phone_number, :password, :password_confirmation, :name)
    # Convert empty strings to nil for optional fields (name is required, so don't convert it)
    permitted[:email] = nil if permitted[:email].blank?
    permitted[:phone_number] = nil if permitted[:phone_number].blank?
    # Name is required, so keep it as is (will be validated by model)
    permitted
  end

  def respond_with(_resource, _opts = {})
    if resource.persisted?
      render json: {
        status: { code: 200, message: "Signed up successfully." },
        data: { 
          id: resource.id, 
          email: resource.email, 
          phone_number: resource.phone_number,
          name: resource.name 
        }
      }
    else
      render json: {
        status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end
end
