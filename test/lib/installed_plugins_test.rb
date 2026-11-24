require "test_helper"

class InstalledPluginsTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    @directory = @root.join("plugins")
    InstalledPlugins.singleton_class.alias_method :original_directory, :directory
    directory = @directory
    InstalledPlugins.define_singleton_method(:directory) { directory }
  end

  teardown do
    InstalledPlugins.singleton_class.alias_method :directory, :original_directory
    InstalledPlugins.singleton_class.remove_method :original_directory
    FileUtils.rm_rf @root
  end

  test "a release that couldn't migrate is set aside and the one it replaced comes back" do
    release "leads", "3.1.0"
    release ".leads.previous", "3.0.0"

    note = quietly { InstalledPlugins.set_aside!("leads", StandardError.new("table \"leads_templates\" already exists")) }

    assert_equal "3.0.0", version_of("leads")
    assert_equal "3.1.0", version_of(".leads.failed")
    assert_not @directory.join(".leads.previous").exist?
    assert_equal({ "version" => "3.1.0", "restored" => "3.0.0" }, InstalledPlugins.set_aside["leads"].slice("version", "restored"))
    assert_match "leads_templates", note[:error]
    assert_equal [ "leads" ], InstalledPlugins.present.keys
  end

  test "without a release to go back to, the install starts without it" do
    release "leads", "3.1.0"

    quietly { InstalledPlugins.set_aside!("leads", StandardError.new("boom")) }

    assert_empty InstalledPlugins.present
    assert_nil InstalledPlugins.set_aside["leads"]["restored"]
  end

  test "the note goes once the plugin is installed again" do
    release "leads", "3.1.0"
    quietly { InstalledPlugins.set_aside!("leads", StandardError.new("boom")) }

    InstalledPlugins.clear_set_aside("leads")

    assert_empty InstalledPlugins.set_aside
  end

  private
    def release(name, version)
      path = @directory.join(name).tap { FileUtils.mkdir_p it }
      path.join("leads.gemspec").write("")
      path.join(InstalledPlugins::METADATA).write({ repo: "acme/runwell-leads", version: version }.to_json)
    end

    def version_of(name) = JSON.parse(@directory.join(name, InstalledPlugins::METADATA).read)["version"]

    def quietly
      original, $stderr = $stderr, StringIO.new
      yield
    ensure
      $stderr = original
    end
end
