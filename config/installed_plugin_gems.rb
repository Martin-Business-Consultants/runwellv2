require "open3"
require "fileutils"

# The gems an installed plugin needs beyond the core's (InstalledPlugins): the runtime
# dependencies its gemspec names. The core's bundle is locked, so a plugin can't join it. Instead
# each plugin gets a Gemfile of its own in RUNWELL_DATA_DIR/plugins/.gems/<ruby>-<platform>: its
# dependencies, with every gem already loaded (the core's, and at boot earlier plugins') pinned at
# the version running. Bundler resolves that, backtracking to versions that fit, takes the pinned
# gems as installed, and installs only the rest there; they're put on the load path from that
# Gemfile's lock. A plugin whose gems can't fit the core's doesn't load, with Bundler's reason.
#
# Resolved as a plugin is put in place (PluginChange) and again on a boot whose Gemfile has changed
# (a new core, another plugin's gems; the directory is per Ruby, so a new Ruby too). Production
# images carry no compiler: a gem that must build a native extension installs only where it's
# published prebuilt for this platform.
module InstalledPluginGems
  extend self

  class Unmet < StandardError; end

  TIMEOUT = 600 # seconds for one plugin's gems

  # Gems the core bundled for plugins until 7.1, which a plugin released before then uses without
  # naming (Bundler.require loaded them): given to a plugin whose code uses one and whose gemspec
  # doesn't name it, and required before it loads, as they were. Goes in 8.0.
  BUNDLED_UNTIL_7_1 = {
    "ruby_llm" => [ [ "~> 2.1.1" ], /\bRubyLLM\b/ ],
    "prawn" => [ [ ">= 2.4", "< 3" ], /\bPrawn\b|require ["']prawn["']/ ],
    "matrix" => [ [], /\bPrawn\b|require ["']prawn["']/ ] # Prawn 2.4 needs it without saying so
  }.freeze

  def directory
    InstalledPlugins.directory.join(".gems", "#{RbConfig::CONFIG["ruby_version"]}-#{Gem::Platform.local}")
  end

  # The gems the core's bundle loaded, before any plugin's (git and path gems aside: rubygems.org
  # can't resolve those, and no plugin asks for them).
  def core = @core ||= Gem.loaded_specs.reject { |name, spec| name == "bundler" || from_git_or_path?(spec) }.freeze

  # Each gem a plugin loaded, by name.
  def activated = @activated ||= {}

  # Resolves and installs what the plugin at path needs (a release about to be put in place).
  def install!(name, path) = resolve(name, path, core)

  # Resolves and installs what's missing, then puts the plugin's gems on the load path (at boot).
  def activate!(name, path)
    fixed = core.merge(activated)
    resolve(name, path, fixed).each do |spec|
      next if fixed.key?(spec.name)

      $LOAD_PATH.concat(spec.full_require_paths)
      Gem.loaded_specs[spec.name] = activated[spec.name] = spec
    end
    implied_gems(name, path).each { require it.first }
  end

  private
    def from_git_or_path?(spec)
      spec.respond_to?(:source) && spec.source.class.name.to_s.match?(/Source::(Git|Path)\z/)
    end

    # The specs its Gemfile's lock names, after installing them if the Gemfile changed or one is
    # missing. Nothing when everything it wants is already loaded (most plugins: just rails).
    def resolve(name, path, fixed)
      wanted = dependencies(name, path).map { [ it.name, *it.requirement.as_list ] } + implied_gems(name, path)
      return [] if wanted.all? { |gem, *requirement| fixed[gem] && Gem::Requirement.new(requirement).satisfied_by?(fixed[gem].version) }

      locked do
        gemfile = directory.join("gemfiles", name, "Gemfile")
        content = gemfile_for(wanted, fixed)
        specs = locked_specs(gemfile, fixed) if gemfile.exist? && gemfile.read == content
        unless specs
          FileUtils.mkdir_p gemfile.dirname
          gemfile.write(content)
          bundle(gemfile)
          specs = locked_specs(gemfile, fixed) or raise Unmet, "its gems installed, but not all of them are there"
        end
        specs
      end
    end

    def dependencies(name, path)
      gemspec = path.join("#{name}.gemspec")
      spec = Dir.chdir(path) { Gem::Specification.load(gemspec.to_s) } or raise Unmet, "its gemspec (#{gemspec.basename}) didn't load"
      spec.runtime_dependencies
    end

    def implied_gems(name, path)
      named = dependencies(name, path).map(&:name)
      sources = path.glob("{app,lib,config}/**/*.rb").map { it.read rescue "" }.join("\n")
      BUNDLED_UNTIL_7_1.filter_map { |gem, (requirement, used)| [ gem, *requirement ] if !named.include?(gem) && sources.match?(used) }
    end

    # The plugin's gems as it asks for them (a gem already loaded also held to that version), then
    # every other loaded gem pinned.
    def gemfile_for(wanted, fixed)
      lines = [ "# Made by Runwell (config/installed_plugin_gems.rb): a plugin's gems, with the ones loaded pinned.", %(source "https://rubygems.org") ]
      lines += wanted.map do |gem, *requirement|
        requirement += [ "= #{fixed[gem].version}" ] if fixed[gem]
        "gem #{[ gem, *requirement ].map(&:inspect).join(", ")}"
      end
      lines += fixed.except(*wanted.map(&:first)).sort.map { |gem, spec| "gem #{gem.inspect}, #{spec.version.to_s.inspect}" }
      lines.join("\n") + "\n"
    end

    # The specs a lock names, each the one loaded or the one installed (the lock lists a gem once per
    # platform; one is here): nil when one is missing.
    def locked_specs(gemfile, fixed)
      lock = Pathname("#{gemfile}.lock")
      return unless lock.exist?

      Bundler::LockfileParser.new(lock.read).specs.group_by(&:name).map do |name, variants|
        next fixed[name] if fixed[name]&.version == variants.first.version

        installed = variants.product(specification_dirs).map { |locked, dir| dir.join("#{locked.full_name}.gemspec") }.find(&:exist?) or return
        Gem::Specification.load(installed.to_s) or return
      end
    end

    # Bundler in a process of its own that knows nothing of the core's bundle: the core's gems are
    # its system gems, already installed, and new ones go to the directory.
    def bundle(gemfile)
      env = {
        "BUNDLE_GEMFILE" => gemfile.to_s, "BUNDLE_APP_CONFIG" => gemfile.dirname.join(".bundle").to_s,
        "GEM_HOME" => directory.to_s, "GEM_PATH" => gem_path.join(File::PATH_SEPARATOR),
        "BUNDLE_PATH" => nil, "BUNDLE_DEPLOYMENT" => nil, "BUNDLE_FROZEN" => nil, "BUNDLE_WITHOUT" => nil, "BUNDLE_WITH" => nil,
        "BUNDLE_BIN" => nil, "RUBYOPT" => nil
      }
      command = [ Gem.ruby, File.join(RbConfig::CONFIG["bindir"], "bundle"), "install", "--prefer-local", "--quiet" ]
      output, status = Bundler.with_unbundled_env { run(env, command, gemfile.dirname) }
      return if status&.success?

      raise Unmet, "its gems couldn't be installed: #{output.lines.map(&:strip).reject(&:empty?).last(6).join(" ")}"
    end

    # Where Bundler finds gems installed: here first, then the core's bundle and Ruby's own.
    def gem_path = [ directory, Bundler.bundle_path, Gem.default_dir ].map(&:to_s).uniq
    def specification_dirs = gem_path.map { Pathname(it).join("specifications") } + [ Pathname(Gem.default_specifications_dir) ]

    def run(env, command, directory)
      Open3.popen2e(env, *command, chdir: directory.to_s) do |stdin, output, wait|
        stdin.close
        reader = Thread.new { output.read }
        unless wait.join(TIMEOUT)
          Process.kill("TERM", wait.pid)
          return [ "no answer after #{TIMEOUT} seconds", nil ]
        end
        [ reader.value.to_s, wait.value ]
      end
    end

    # One process at a time installs (the web and the jobs may boot together).
    def locked
      FileUtils.mkdir_p directory
      File.open(directory.join(".lock"), File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end
end
