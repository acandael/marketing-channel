class Practitioner::SettingsController < Practitioner::BaseController
  def show
  end

  def update
    case params[:section]
    when "password"
      update_password
    when "email"
      request_email_change
    else
      redirect_to practitioner_settings_path, alert: "Unknown settings section."
    end
  end

  private

  def update_password
    unless Current.user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "Current password is incorrect."
      return render :show, status: :unprocessable_content
    end

    new_password = params[:new_password].to_s
    if new_password.length < 8
      flash.now[:alert] = "New password must be at least 8 characters."
      return render :show, status: :unprocessable_content
    end
    if new_password != params[:new_password_confirmation].to_s
      flash.now[:alert] = "Password confirmation does not match."
      return render :show, status: :unprocessable_content
    end

    Current.user.update!(password: new_password)
    redirect_to practitioner_settings_path, notice: "Password updated."
  end

  def request_email_change
    new_email = params[:new_email_address].to_s.strip.downcase
    unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = "Please provide a valid email address."
      return render :show, status: :unprocessable_content
    end

    if User.active.where.not(id: Current.user.id).exists?(email_address: new_email)
      flash.now[:alert] = "That email is already in use."
      return render :show, status: :unprocessable_content
    end

    Current.user.start_email_change!(new_email)
    EmailChangeMailer.with(user: Current.user).confirm.deliver_later

    redirect_to practitioner_settings_path,
                notice: "Check #{new_email} for a confirmation link. It expires in 24 hours."
  end
end
