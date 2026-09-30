# Updates a plain install (bin/install) by running `bin/update <tag>` in the background, as the
# app's own user: fetch and check out the release, bundle, back up and migrate, compile assets,
# restart Puma. Its output and exit status go to updates/<id>/ in the data directory. The
# checkout must belong to that user and be able to fetch from the repository.
class Upgrade::Local
  def initialize(upgrade)
    @upgrade = upgrade
  end

  def start
    FileUtils.mkdir_p directory
    Bundler.with_unbundled_env do
      pid = Process.spawn("/bin/bash", "-c", %(bin/update "$1" > "$2" 2>&1; echo $? > "$3"), "update", @upgrade.tag, log.to_s, exit_status.to_s,
        chdir: Rails.root.to_s, pgroup: true, in: File::NULL, out: File::NULL, err: File::NULL)
      Process.detach(pid)
    end
  end

  # bin/update finished: a non-zero exit fails the upgrade with the end of its output. A zero
  # exit waits for Puma to come back on the new version.
  def check
    return unless exit_status.exist?

    code = exit_status.read.strip
    @upgrade.fail! "bin/update stopped (exit #{code}):\n#{log_tail}" unless code == "0"
  end

  def where_to_look = "Its output is in #{log}."

  private
    def directory = Runwell.data_dir.join("updates", @upgrade.id.to_s)
    def log = directory.join("update.log")
    def exit_status = directory.join("exit_status")

    def log_tail = log.exist? ? log.readlines.last(20).join : "(no output)"
end
