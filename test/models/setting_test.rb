require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "the sender falls back to the default, half by half" do
    setting = Setting.new

    assert_equal Setting.default_mail_sender, setting.mail_sender

    setting.mail_from_name = "Acme, Inc"
    assert_equal %("Acme, Inc" <#{Mail::Address.new(Setting.default_mail_sender).address}>), setting.mail_sender

    setting.mail_from_name = nil
    setting.mail_from_email = "hello@acme.test"
    assert_equal "Runwell <hello@acme.test>", setting.mail_sender
  end

  test "blank sender fields are kept as nothing" do
    setting = Setting.new(mail_from_name: "  ", mail_from_email: "")

    assert_nil setting.mail_from_name
    assert_nil setting.mail_from_email
    assert setting.valid?
  end
end
