class EmailVerificationMailer < ApplicationMailer
  def verification_code_email(user, code)
    @user = user
    @code = code
    @app_name = "ChopBill"
    
    mail(
      to: @user.email,
      subject: "#{@app_name} - Verify your email address"
    )
  end
end

