require "test_helper"

# Action Mailbox's ingresses open only for the service a receiving plugin names (7.0).
class MailIngressTest < ActionDispatch::IntegrationTest
  RAW = "From: someone@example.com\r\nTo: requests@example.com\r\nSubject: Hello\r\nMessage-ID: <ingress-test@example.com>\r\n\r\nHi\r\n".freeze

  setup do
    Runwell::Plugins.register :mail_test, name: "Mail test", version: "0.1.0", description: "Receives mail in tests."
    Runwell::Plugins.receive_mail :mail_test, mailbox: "ApplicationMailbox", ingress: -> { :relay }, password: -> { "secret" }
  end

  teardown do
    Runwell::Plugins.manifests.delete(:mail_test)
    Runwell::Plugins.mail_receivers.delete(:mail_test)
  end

  test "the relay answers 404 while no plugin receives mail" do
    post rails_relay_inbound_emails_url, params: RAW, headers: relay_headers("secret")

    assert_response :not_found
  end

  test "the relay takes mail signed with the receiving plugin's password, and only that" do
    Setting.current.toggle_plugin!(:mail_test, enabled: true)

    post rails_relay_inbound_emails_url, params: RAW, headers: relay_headers("wrong")
    assert_response :unauthorized

    assert_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_relay_inbound_emails_url, params: RAW, headers: relay_headers("secret")
    end
    assert_response :no_content
  end

  private
    def relay_headers(password)
      { "Content-Type" => "message/rfc822", "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", password) }
    end
end
