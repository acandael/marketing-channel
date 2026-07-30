class EmailChangeMailer < ApplicationMailer
  def confirm
    @user = params[:user]
    @confirm_url = confirm_email_change_url(token: @user.email_change_token)
    @expires_at = @user.email_change_sent_at + User::EMAIL_CHANGE_LIFETIME

    mail to: @user.pending_email_address, subject: "Confirm your new email"
  end
end
