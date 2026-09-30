# The runwell CLI, served by the app so it always matches this install: /install/cli is a shell
# installer, /install/runwell the single-file Ruby script with this install's address baked in.
class CliController < ApplicationController
  allow_unauthenticated_access

  SCRIPT = Rails.root.join("lib/cli/runwell")

  def install
    render plain: <<~SH, content_type: "text/x-shellscript"
      #!/bin/sh
      # Installs the runwell CLI for #{root_url}
      set -e
      command -v ruby >/dev/null 2>&1 || { echo "runwell needs Ruby (macOS has it; on Linux: apt install ruby)"; exit 1; }
      dir="${RUNWELL_BIN:-$HOME/.local/bin}"
      mkdir -p "$dir"
      curl -fsSL "#{cli_script_url}" -o "$dir/runwell"
      chmod +x "$dir/runwell"
      echo "Installed runwell to $dir/runwell."
      echo "Next: runwell login   (and runwell agent setup to teach Claude Code)"
    SH
  end

  def show
    render plain: SCRIPT.read.sub("__RUNWELL_URL__", root_url.chomp("/")), content_type: "text/x-ruby"
  end
end
