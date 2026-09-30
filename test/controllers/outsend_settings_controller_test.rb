require "test_helper"

# The Outsend plugin's page: the key only. Who mail comes from is the install's sender.
class OutsendSettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ted) }

  test "show names the install's sender and links to where it is set" do
    Setting.current.update!(mail_from_email: "hello@brem.io")

    get outsend_settings_path

    assert_response :success
    assert_match "hello@brem.io", response.body
    assert_select "a[href='#{settings_email_path}']"
    assert_select "input[name='connection[from_email]']", count: 0
  end

  test "a blank key is asked for again" do
    patch outsend_settings_path, params: { connection: { api_key: "" } }

    assert_equal "Paste the API key.", flash[:alert]
    assert_nil Outsend::Connection.current
  end
end
