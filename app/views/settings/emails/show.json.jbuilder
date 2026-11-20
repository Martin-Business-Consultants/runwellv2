json.summary "Mail comes from #{@setting.mail_sender}"
json.sender @setting.mail_sender
json.from_name @setting.mail_from_name
json.from_email @setting.mail_from_email
json.default_sender Setting.default_mail_sender
json.delivery_method ActionMailer::Base.delivery_method
json.test_email @setting.test_email
