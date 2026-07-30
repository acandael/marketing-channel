class EmailChangeMailerPreview < ActionMailer::Preview
  def confirm
    user = User.where.not(email_change_token: nil).first
    user ||= User.new(
      email_address: "current@example.com",
      pending_email_address: "new@example.com",
      email_change_token: "sample-preview-token",
      email_change_sent_at: Time.current
    )
    EmailChangeMailer.with(user: user).confirm
  end
end
