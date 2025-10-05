class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_signed_out_user, only: :destroy
  respond_to :json

  # POST /login
  def create
    authenticated_resource = warden.authenticate(auth_options)
    unless authenticated_resource
      return render json: {
        status: { code: 401, message: "Invalid email or password." }
      }, status: :unauthorized
    end
    self.resource = authenticated_resource
    # no cookie session
    sign_in(resource_name, resource, store: false)

    # Explicitly generate and expose JWT in both header and body
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil)
    response.set_header("Authorization", "Bearer #{token}")

    user_json = {
      id: resource.id,
      email: resource.email,
      name: resource.name
    }

    render json: {
      status: { code: 200, message: "Logged in successfully." },
      data: user_json,
      token: token
    }, status: :ok
  end

  # DELETE /logout
  def destroy
    # Revoke JWT using Devise's revocation strategy (e.g., JTIMatcher)
    if current_user
      sign_out(resource_name)
      render json: { status: 200, message: "Logged out successfully." }, status: :ok
    else
      render json: { status: 401, message: "No active session or invalid token." }, status: :unauthorized
    end
  end

  private

  def respond_with(_resource, _opts = {})
    render json: {
      status: { code: 200, message: "Logged in successfully." },
      data: {
        id: resource.id,
        email: resource.email,
        name: resource.name
      }
    }, status: :ok
  end
end
