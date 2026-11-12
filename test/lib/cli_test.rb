require "test_helper"
require "open3"
require "socket"
require "tmpdir"

# The runwell CLI (lib/cli/runwell) run as a person would, in a home of its own, against a
# stand-in Runwell on a local port: what it keeps when signed in to several, and which sign-in
# goes where.
class CliTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("lib/cli/runwell").to_s

  setup do
    @home = Dir.mktmpdir("runwell-cli")
    @servers = []
  end

  teardown do
    @servers.each { it[:thread].kill; it[:socket].close }
    FileUtils.remove_entry(@home)
  end

  test "signing in to a second Runwell keeps the first, and its default" do
    cli "login", "https://one.test", "--token", "one-token", "--client"
    out, = cli "login", "https://two.test", "--token", "two-token", "--client"

    assert_match "Your default is still one.test", out
    assert_equal %w[https://one.test https://two.test], saved["installs"].keys
    assert_equal "one-token", saved.dig("installs", "https://one.test", "token")
    assert_equal "https://one.test", saved["default"]
    assert_equal 0o600, File.stat(logins_path).mode & 0o777
  end

  test "use picks the default, by host, and only among the Runwells signed in to" do
    cli "login", "https://one.test", "--token", "one-token", "--client"
    cli "login", "https://two.test", "--token", "two-token", "--client"

    cli "use", "two.test"
    assert_equal "https://two.test", saved["default"]
    assert_equal [ false, true ], JSON.parse(cli("installs").first)["installs"].map { it["default"] }

    _, error, status = cli "use", "three.test"
    assert_equal 4, status.exitstatus
    assert_match "not signed in to three.test", error
  end

  test "logout signs out of one and leaves the other, which becomes the default" do
    cli "login", "https://one.test", "--token", "one-token", "--client"
    cli "login", "https://two.test", "--token", "two-token", "--client"

    out, = cli "logout", "one.test"
    assert_match "Signed out of one.test. Still signed in to two.test.", out
    assert_equal [ "https://two.test" ], saved["installs"].keys
    assert_equal "https://two.test", saved["default"]

    cli "logout", "--all"
    assert_empty saved["installs"]
  end

  test "the one sign-in an older CLI kept carries over" do
    FileUtils.mkdir_p(File.dirname(logins_path))
    legacy = File.join(File.dirname(logins_path), "config.json")
    File.write(legacy, JSON.generate("url" => "https://one.test/", "token" => "one-token", "refresh_token" => "r", "mcp_path" => "/mcp"))

    assert_equal [ "one.test" ], JSON.parse(cli("installs").first)["installs"].map { it["host"] }

    cli "login", "https://two.test", "--token", "two-token", "--client"
    assert_not File.exist?(legacy)
    assert_equal "https://one.test", saved["default"]
    assert_equal({ "token" => "one-token", "refresh_token" => "r", "mcp_path" => "/mcp" }, saved.dig("installs", "https://one.test"))
  end

  test "a sign-in is only ever sent to its own Runwell" do
    other = runwell
    cli "login", "https://one.test", "--token", "one-token", "--client"

    # Pointed at another address, the default's token stays home: nothing is sent at all.
    _, error, status = cli "tools", env: { "RUNWELL_URL" => other[:url] }
    assert_equal 4, status.exitstatus
    assert_match "not signed in to #{other[:host]}", error
    assert_empty other[:requests]

    cli "login", other[:url], "--token", "other-token"
    out, = cli "tools", "--on", other[:host]
    assert_match "ping", out
    assert_equal [ "Bearer other-token" ], other[:requests].map { it[:authorization] }.uniq
    assert_equal "https://one.test", saved["default"]
  end

  test "with several signed in, what to run next says which Runwell" do
    here = runwell
    cli "login", "https://one.test", "--token", "one-token", "--client"
    cli "login", here[:url], "--token", "here-token"

    out, = cli "ping", "--on", here[:host]
    assert_equal "runwell show_task --id 1 --on #{here[:host]}", JSON.parse(out).dig("next", 0, "command")
  end

  test "an expired token is refreshed once, and the new pair kept for that Runwell" do
    here = runwell(expired: "old-token")
    FileUtils.mkdir_p(File.dirname(logins_path))
    File.write(logins_path, JSON.generate("default" => "https://one.test", "installs" => {
      "https://one.test" => { "token" => "one-token", "mcp_path" => "/mcp" },
      here[:url] => { "token" => "old-token", "refresh_token" => "old-refresh", "client_id" => "c", "token_endpoint" => "#{here[:url]}/oauth/token", "mcp_path" => "/mcp" } }))

    out, = cli "ping", "--on", here[:host]
    assert_equal "ok", JSON.parse(out)["status"]
    assert_equal "new-token", saved.dig("installs", here[:url], "token")
    assert_equal "new-refresh", saved.dig("installs", here[:url], "refresh_token")
    assert_equal "one-token", saved.dig("installs", "https://one.test", "token")
    assert_equal 1, here[:requests].count { it[:path] == "/oauth/token" }
  end

  test "agent setup writes to this Claude Code's own directory, and --on ties it to a Runwell" do
    claude = File.join(@home, ".claude-work")
    cli "login", "https://one.test", "--token", "one-token", "--client"
    cli "login", "https://two.test", "--token", "two-token", "--client"

    cli "agent", "setup", "--on", "two.test", env: { "CLAUDE_CONFIG_DIR" => claude }
    settings = JSON.parse(File.read(File.join(claude, "settings.json")))

    assert File.exist?(File.join(claude, "skills", "runwell", "SKILL.md"))
    assert_equal "https://two.test", settings.dig("env", "RUNWELL_URL")
    assert_match "doctor --brief", settings.dig("hooks", "SessionStart", 0, "hooks", 0, "command")
    assert_not File.exist?(File.join(@home, ".claude"))
  end

  private
    def cli(*args, env: {})
      Open3.capture3({ "HOME" => @home, "XDG_CONFIG_HOME" => File.join(@home, ".config"), "RUNWELL_URL" => nil, "CLAUDE_CONFIG_DIR" => nil }.merge(env),
        RbConfig.ruby, SCRIPT, *args)
    end

    def logins_path = File.join(@home, ".config", "runwell", "logins.json")
    def saved = JSON.parse(File.read(logins_path))

    # A Runwell that answers /mcp (one tool, ping) and /oauth/token, and remembers what it was sent.
    def runwell(expired: nil)
      socket = TCPServer.new("127.0.0.1", 0)
      server = { socket: socket, requests: [], host: "127.0.0.1:#{socket.addr[1]}", url: "http://127.0.0.1:#{socket.addr[1]}" }
      server[:thread] = Thread.new do
        loop do
          client = socket.accept
          path = client.gets.to_s.split[1]
          headers = {}
          while (line = client.gets.to_s.strip) != ""
            name, value = line.split(": ", 2)
            headers[name.downcase] = value
          end
          body = client.read(headers["content-length"].to_i)
          server[:requests] << { path: path, authorization: headers["authorization"], body: body }
          code, answer = respond(path, headers["authorization"], body, expired)
          client.print "HTTP/1.1 #{code}\r\nContent-Type: application/json\r\nContent-Length: #{answer.bytesize}\r\nConnection: close\r\n\r\n#{answer}"
          client.close
        end
      end
      @servers << server
      server
    end

    def respond(path, authorization, body, expired)
      return [ "200 OK", JSON.generate(access_token: "new-token", refresh_token: "new-refresh") ] if path == "/oauth/token"
      return [ "401 Unauthorized", "{}" ] if expired && authorization == "Bearer #{expired}"

      result = if JSON.parse(body)["method"] == "tools/list"
        { tools: [ { name: "ping", title: "Ping", inputSchema: { type: "object", properties: {} } } ] }
      else
        { structuredContent: { status: "ok", next: [ { tool: "show_task", title: "Open it", command: "runwell show_task --id 1" } ] } }
      end
      [ "200 OK", JSON.generate(jsonrpc: "2.0", id: 1, result: result) ]
    end
end
