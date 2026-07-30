class Public::EmailChangesController < Public::BaseController
  def show
    user = User.active.find_by(email_change_token: params[:token])

    if user.nil?
      render :error,
             locals: { title: "Link not valid", body: "This confirmation link isn't valid. It may have already been used." },
             status: :not_found
      return
    end

    if user.email_change_expired?
      render :error,
             locals: { title: "Link expired", body: "This email-change link has expired. Please request a new one from your settings." },
             status: :gone
      return
    end

    if user.confirm_email_change!
      redirect_to new_session_path,
                  notice: "Email confirmed. Sign in with your new email address."
    else
      render :error,
             locals: { title: "Could not confirm email", body: "Something went wrong. Please try again from your settings." },
             status: :unprocessable_content
    end
  end
end
