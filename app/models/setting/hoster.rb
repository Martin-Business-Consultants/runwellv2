# Updates through KamalCloud (Upgrade::Hoster): the token Settings > Updates was given, from the
# KamalCloud install this runs on (an admin's, Settings > Connected apps there). Encrypted.
module Setting::Hoster
  extend ActiveSupport::Concern

  included do
    encrypts :hoster_token
  end
end
