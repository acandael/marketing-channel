class AdminNotificationMailer < ApplicationMailer
  def account_deleted
    @admin_email = params[:admin_email]
    @practitioner = params[:practitioner]
    @deleted_email = params[:deleted_email]

    mail to: @admin_email, subject: "Practitioner account deleted: #{@practitioner.full_name}"
  end
end
