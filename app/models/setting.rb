# This install's settings, one row: one install is one business (or household, or whatever it
# runs). Each area is a concern of its own: how it looks, where it's reached, its time zone, mail,
# bot checks, what it calls things and which plugins are on.
class Setting < ApplicationRecord
  include Eventful, CustomCss
  include Appearance, Address, TimeZone, Mail, BotCheck, Terminology, Plugins, Layouts

  def self.current
    Current.settings ||= first_or_create!
  end
end
