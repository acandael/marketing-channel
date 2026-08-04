class ApplicationMailer < ActionMailer::Base
  default from: -> {
    ENV["MAIL_FROM"] ||
      Rails.application.credentials.dig(:mail, :from) ||
      "Holistic Health <no-reply@heal-and-grow.org>"
  }

  layout "mailer"
end
