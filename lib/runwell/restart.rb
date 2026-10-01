# Restarts this install so it boots on changed code: a core release it updated to in place, or
# a plugin installed, updated or removed. A few seconds later, so the request or job that asked
# has finished. In its Docker image the container's main process stops and Docker's restart
# policy (Kamal's unless-stopped) starts it again, migrating on boot (bin/docker-entrypoint);
# anywhere else it migrates, then asks Puma to restart (its tmp_restart plugin). A plugin's
# assets compile as it boots (config/initializers/installed_plugins.rb).
module Runwell::Restart
  extend self

  def later(delay: 5)
    if ENV["RUNWELL_RUNTIME"] == "docker"
      Thread.new do
        sleep delay
        Process.kill "TERM", 1
      end
    else
      Bundler.with_unbundled_env do
        pid = Process.spawn("/bin/bash", "-c", %(sleep #{Integer(delay)}; bin/rails db:migrate && bin/rails restart),
          chdir: Rails.root.to_s, pgroup: true, in: File::NULL, out: Rails.root.join("log/restart.log").to_s, err: [ :child, :out ])
        Process.detach(pid)
      end
    end
  end
end
