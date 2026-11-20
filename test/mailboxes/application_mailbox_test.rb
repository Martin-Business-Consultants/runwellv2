require "test_helper"

# Mail in (7.0): the core receives none itself; a switched-on plugin that registered with
# Runwell::Plugins.receive_mail gets every message, through the service it names.
class ApplicationMailboxTest < ActionMailbox::TestCase
  class TestMailbox < ActionMailbox::Base
    cattr_accessor :received, default: []
    def process = received << mail.subject
  end

  setup do
    TestMailbox.received = []
    Runwell::Plugins.register :mail_test, name: "Mail test", version: "0.1.0", description: "Receives mail in tests."
  end

  teardown do
    Runwell::Plugins.manifests.delete(:mail_test)
    Runwell::Plugins.mail_receivers.delete(:mail_test)
  end

  test "with no plugin receiving, mail is bounced and no ingress is open" do
    inbound_email = receive_inbound_email_from_mail(from: "someone@example.com", to: "requests@example.com", subject: "Hello")

    assert inbound_email.bounced?
    assert_nil Runwell::Plugins.mail_ingress
  end

  test "a switched-on plugin's mailbox gets the mail, through the service it names" do
    Runwell::Plugins.receive_mail :mail_test, mailbox: "ApplicationMailboxTest::TestMailbox", ingress: -> { :relay }, password: -> { "secret" }
    Setting.current.toggle_plugin!(:mail_test, enabled: true)

    inbound_email = receive_inbound_email_from_mail(from: "someone@example.com", to: "requests@example.com", subject: "Hello")

    assert inbound_email.delivered?
    assert_equal [ "Hello" ], TestMailbox.received
    assert_equal :relay, Runwell::Plugins.mail_ingress
    assert_equal "secret", Runwell::Plugins.mail_ingress_password
  end

  test "a plugin that's switched off receives nothing, and an unknown service opens no ingress" do
    Runwell::Plugins.receive_mail :mail_test, mailbox: "ApplicationMailboxTest::TestMailbox", ingress: -> { :carrier_pigeon }

    assert_nil Runwell::Plugins.mail_receiver
    Setting.current.toggle_plugin!(:mail_test, enabled: true)
    assert_nil Runwell::Plugins.mail_ingress
  end
end
