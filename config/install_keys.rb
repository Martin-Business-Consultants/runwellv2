# An install's own keys, so a deploy needs no secrets set by hand: SECRET_KEY_BASE and Active Record
# encryption's three keys. Any set in the environment win (bin/install's .env, a Kamal destination,
# Hoster's template). Any missing are read from RUNWELL_DATA_DIR/keys.env, which the first boot of
# a new install writes, so they live in the same volume as the data they unlock.
#
# Production only, and not when the install uses a credentials file (RAILS_MASTER_KEY or
# config/master.key) or while assets compile (SECRET_KEY_BASE_DUMMY). A database that already
# exists never gets new keys: they couldn't read what's encrypted in it, so the boot stops and
# says which keys to put back.
require "securerandom"
require "fileutils"

module InstallKeys
  NAMES = {
    "SECRET_KEY_BASE" => -> { SecureRandom.hex(64) },
    "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => -> { SecureRandom.alphanumeric(32) },
    "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => -> { SecureRandom.alphanumeric(32) },
    "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => -> { SecureRandom.alphanumeric(32) }
  }.freeze

  class << self
    def load!
      return unless applies?

      missing = NAMES.keys.select { |name| blank?(ENV[name]) }
      return if missing.empty?

      saved = read
      missing.each { |name| ENV[name] = saved[name] unless blank?(saved[name]) }
      missing = missing.select { |name| blank?(ENV[name]) }
      return if missing.empty?

      if File.exist?(File.join(data_dir, "production.sqlite3"))
        abort <<~MESSAGE
          Runwell's database exists but these keys are missing: #{missing.join(", ")}.
          New ones couldn't read what's encrypted in it. Set the ones this install was using in its
          environment, or put them back in #{file}.
        MESSAGE
      end

      missing.each { |name| ENV[name] = saved[name] = NAMES.fetch(name).call }
      write saved
    end

    def file = File.join(data_dir, "keys.env")

    private
      def applies?
        (ENV["RAILS_ENV"] || ENV["RACK_ENV"]) == "production" &&
          blank?(ENV["SECRET_KEY_BASE_DUMMY"]) && blank?(ENV["RAILS_MASTER_KEY"]) &&
          !File.exist?(File.expand_path("master.key", __dir__))
      end

      def data_dir = File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), File.expand_path("..", __dir__))

      def read
        return {} unless File.exist?(file)

        File.readlines(file, chomp: true).filter_map { |line|
          line.split("=", 2) if line.match?(/\A[A-Z_]+=/)
        }.to_h
      end

      def write(keys)
        FileUtils.mkdir_p(data_dir)
        body = <<~HEADER + keys.map { |name, value| "#{name}=#{value}\n" }.join
          # This install's keys, written by its first boot (config/install_keys.rb). Keep a copy
          # elsewhere: without the three encryption keys, a restored database can't read the API
          # keys and tokens stored in it. Any set in the environment are used instead.
        HEADER
        temp = "#{file}.#{Process.pid}"
        File.open(temp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |f| f.write(body) }
        File.rename(temp, file)
      end

      def blank?(value) = value.nil? || value.strip.empty?
  end
end

InstallKeys.load!
