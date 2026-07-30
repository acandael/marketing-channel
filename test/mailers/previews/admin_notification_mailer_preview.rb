class AdminNotificationMailerPreview < ActionMailer::Preview
  def account_deleted
    practitioner = Practitioner.first || Practitioner.new(full_name: "Sample Practitioner", city: "Berlin")
    AdminNotificationMailer.with(
      admin_email: "admin@example.com",
      practitioner: practitioner,
      deleted_email: "deleted-user@example.com"
    ).account_deleted
  end
end
