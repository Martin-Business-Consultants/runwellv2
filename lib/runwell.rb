# The core's own name and version. The VERSION file is the one place the version is written;
# it is shown in Settings and is what a plugin's `requires:` is checked against.
module Runwell
  VERSION = Rails.root.join("VERSION").read.strip

  # Where this install keeps its state: databases, uploaded files, backups and update logs.
  def self.data_dir = Pathname(File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), Rails.root))
end
