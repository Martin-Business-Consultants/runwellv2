# Mail reaches Runwell only through the inbound service the install names (INBOUND_EMAIL_INGRESS),
# forwarding the requests address, so everything it hands over is a request or a reply to one.
class ApplicationMailbox < ActionMailbox::Base
  routing all: :requests
end
