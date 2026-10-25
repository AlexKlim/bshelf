class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Book Shelf <no-reply@localhost>")
  layout "mailer"
end
