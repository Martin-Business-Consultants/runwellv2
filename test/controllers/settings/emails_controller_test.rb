require "test_helper"

class Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { sign_in_as users(:ted) }

  test "show" do
    get settings_email_path

    assert_response :success
    assert_select "input[name='setting[mail_from_email]']"
  end

  test "saving the sender puts it on every email" do
    patch settings_email_path, params: { setting: { mail_from_name: "Brem", mail_from_email: "hello@brem.io" } }

    assert_redirected_to settings_email_path
    assert_equal "Brem <hello@brem.io>", Setting.current.reload.mail_sender

    post settings_email_test_message_path, params: { to: "someone@example.com" }

    assert_redirected_to settings_email_path
    assert_equal [ "hello@brem.io" ], ActionMailer::Base.deliveries.last.from
    assert_equal "Brem", ActionMailer::Base.deliveries.last[:from].display_names.first
  end

  test "an address that isn't one is refused" do
    patch settings_email_path, params: { setting: { mail_from_email: "not an address" } }

    assert_redirected_to settings_email_path
    assert_match "should be an email address", flash[:alert]
    assert_nil Setting.current.reload.mail_from_email
  end

  test "someone who can't manage settings can't change the sender" do
    sign_in_as users(:sarah)

    patch settings_email_path, params: { setting: { mail_from_email: "hello@brem.io" } }

    assert_nil Setting.current.reload.mail_from_email
  end
end
