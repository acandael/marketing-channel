class Practitioner::AccountsController < Practitioner::BaseController
  before_action :block_impersonator, only: :destroy

  def destroy
    user = Current.user
    practitioner = @practitioner
    email = user.email_address

    ActiveRecord::Base.transaction do
      user.update!(deleted_at: Time.current)
      practitioner.update!(user_id: nil, claimed_at: nil)
    end

    admin_email = admin_notification_address
    if admin_email.present?
      AdminNotificationMailer.with(
        admin_email: admin_email,
        practitioner: practitioner,
        deleted_email: email
      ).account_deleted.deliver_later
    end

    terminate_session
    redirect_to root_path,
                notice: "Your account has been deleted. Your listing is now unclaimed; an admin can re-invite you if you change your mind."
  end

  private

  def block_impersonator
    return unless Current.impersonating?
    redirect_to practitioner_settings_path,
                alert: "You can't delete an account while impersonating it."
  end

  def admin_notification_address
    Rails.application.credentials.dig(:admin, :notification_email) ||
      ENV["ADMIN_NOTIFICATION_EMAIL"].presence ||
      User.admin.active.order(:id).first&.email_address
  end
end
