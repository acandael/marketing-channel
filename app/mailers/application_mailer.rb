class ApplicationMailer < ActionMailer::Base
  default from: -> {
    Rails.application.credentials.dig(:mail, :from) ||
      ENV["MAIL_FROM"] ||
      "Marketing Channel <no-reply@marketing-channel.example>"
  }

  layout "mailer"
end
