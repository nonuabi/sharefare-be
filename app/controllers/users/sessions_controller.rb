class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_signed_out_user, only: :destroy
  respond_to :json

  # POST /login
  def create
    # Support login with email or phone_number
    login_param = params[:user]&.dig(:login) || params[:user]&.dig(:email) || params[:user]&.dig(:phone_number)
    password = params[:user]&.dig(:password)
    
    unless login_param && password
      return render json: {
        error: 'Login failed',
        message: 'Please provide your email or phone number and password.'
      }, status: :unauthorized
    end

    # Find user by email or phone_number
    user = User.find_for_database_authentication(login: login_param)
    
    unless user && user.valid_password?(password)
      return render json: {
        error: 'Login failed',
        message: 'Invalid email/phone or password. Please check your credentials and try again.'
      }, status: :unauthorized
    end

    self.resource = user
    sign_in(resource_name, resource, store: false)

    # Explicitly generate and expose JWT in both header and body
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil)
    response.set_header('Authorization', "Bearer #{token}")

    user_json = {
      id: resource.id,
      email: resource.email,
      phone_number: resource.phone_number,
      name: resource.name
    }

    render json: {
      status: { code: 200, message: 'Logged in successfully.' },
      data: user_json,
      token: token
    }, status: :ok
  end

  # DELETE /logout
  def destroy
    # Revoke JWT using Devise's revocation strategy (e.g., JTIMatcher)
    if current_user
      sign_out(resource_name)
      render json: { status: 200, message: 'Logged out successfully.' }, status: :ok
    else
      render json: { status: 401, message: 'No active session or invalid token.' }, status: :unauthorized
    end
  end

  private

  def respond_with(_resource, _opts = {})
    render json: {
      status: { code: 200, message: 'Logged in successfully.' },
      data: {
        id: resource.id,
        email: resource.email,
        phone_number: resource.phone_number,
        name: resource.name
      }
    }, status: :ok
  end
end
