class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  # POST /signup
  def create
    build_resource(sign_up_params)

    if resource.save
      sign_in(resource_name, resource, store: false)

      token, _payload = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil)
      response.set_header("Authorization", "Bearer #{token}")

      user_json = { id: resource.id, email: resource.email, name: resource.name }

      render json: {
        status: { code: 201, message: "Signed up successfully." },
        data: user_json,
        token: token
      }, status: :created
    else
      render json: { status: { code: 422, message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" } },
             status: :unprocessable_entity
    end
  end

  private

  def respond_with(_resource, _opts = {})
    if resource.persisted?
      render json: {
        status: { code: 200, message: "Signed up successfully." },
        data: { id: resource.id, email: resource.email, name: resource.name }
      }
    else
      render json: {
        status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end
end
