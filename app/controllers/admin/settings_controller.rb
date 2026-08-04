class Admin::SettingsController < Admin::BaseController
  def show
  end

  def update
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
    redirect_to admin_settings_path, notice: "Password updated."
  end
end
