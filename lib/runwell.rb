# The core's own name and version. The VERSION file is the one place the version is written;
# it is shown in Settings and is what a plugin's `requires:` is checked against.
module Runwell
  VERSION = Rails.root.join("VERSION").read.strip

  # Where this install keeps its state: databases, uploaded files, backups and update logs.
  def self.data_dir = Pathname(File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), Rails.root))

  # This install's address, for links made outside a request (mail, approval links): the one an
  # owner set in Settings > Address, else APP_HOST, else the one people were last seen using.
  def self.host = Setting.current.app_host.presence || ENV["APP_HOST"].presence || Setting.current.seen_host.presence || "localhost"
  def self.protocol = Setting.current.app_protocol.presence || ENV["APP_PROTOCOL"].presence || "https"
  def self.url = "#{protocol}://#{host}"

  # Whether anyone has said where Runwell lives (a setting or APP_HOST), rather than it being guessed.
  def self.host_set? = Setting.current.app_host.present? || ENV["APP_HOST"].present?
end
