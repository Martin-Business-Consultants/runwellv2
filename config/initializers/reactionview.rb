# frozen_string_literal: true

ReActionView.configure do |config|
  # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
  config.intercept_erb = true

  # Reactive templates: `herb:state`, `data-herb-*` actions and components with slots
  config.slots = true

  # Enable debug mode in development (adds debug attributes to HTML)
  config.debug_mode = Rails.env.development?

  # Path used for editor "open in editor" links (optional, defaults to Rails.root)
  # config.project_path = ENV.fetch('PROJECT_PATH', Rails.root.to_s)

  # Validation mode (:raise, :overlay, or :none) — defaults to :raise in test, :overlay otherwise
  # config.validation_mode = :overlay

  # How to handle templates that come from gems (:fallback, :skip, or :compile), defaults to :fallback
  # config.external_template_mode = :skip

  # Measure what a page does while it renders, and show it in the dev tools.
  # Follows development unless you say otherwise, and each measurement can be turned off.
  # config.instrumentation.enabled = Rails.env.development?
  # config.instrumentation.sql_queries = false
  # config.instrumentation.render_times = false
  # config.instrumentation.translations = false

  # Add visitors to the compile. Place them with `insert_before` and `insert_after`.
  # config.engine.visitors.use(Herb::Visitor.new)

  # Parser options for every compile, merged over the ones in .herb.yml
  # config.engine.parser_options = { strict_locals: true }
end

# ReActionView only gives the app's own app/views its slots resolver, so a plugin's partials
# (plugin_slots) were missing whenever a state change re-rendered the page. Plugins get it too.
ActiveSupport.on_load(:action_controller_base) do
  Rails.application.railties.grep(Rails::Engine).each do |engine|
    next unless engine.root.to_s.start_with?(Rails.root.join("engines").to_s)

    engine.paths["app/views"].existent.each { prepend_view_path ReActionView::Slots::Resolver.new(it) }
  end
end

# ReActionView works out which state each page depends on after every render, and Herb 0.11's
# analysis re-reads and re-parses the page and every partial it reaches each time: about 175
# parses and 350ms on a piece of work page, for the same answer. An analysis depends only on the
# file, so keep each one until the file changes.
Herb::Analysis::TemplateDependencies.prepend(Module.new do
  def analyze(file_path)
    path = Pathname.new(file_path).absolute? ? file_path.to_s : @project_path.join(file_path).to_s
    stat = File.stat(path)
    key = [ path, stat.mtime.to_r, stat.size ]
    (@analyses ||= {})[path]&.then { |cached_key, analysis| return analysis if cached_key == key }

    super.tap { @analyses[path] = [ key, it ] }
  end
end)

# After every render, ReActionView sends the page's slot dependency map (which state each slot
# reads), and Herb 0.11 rebuilds it from the templates each time: 30-50ms a page, more than the
# page's own templates take, for the same answer. The map depends only on the template files (the
# render passes no params), so keep each page's until a view changes: once per boot where code
# doesn't reload, and in development until a template's modified time moves on.
# (Not under Runwell::, which an initializer would define before lib/runwell.rb autoloads.)
module SlotEnvelopeCache
  ENVELOPES = Concurrent::Map.new

  def self.views_version
    return :static unless Rails.application.config.enable_reloading

    Dir.glob(Rails.root.join("{app,engines}/**/views/**/*.erb").to_s).map { File.mtime(it).to_r }.max
  end

  def envelope(entry_point, params: {})
    return super unless params.empty?

    ENVELOPES.compute_if_absent([ entry_point.to_s, SlotEnvelopeCache.views_version ]) { super }
  end
end
Herb::Engine::Slots::Dependencies.prepend(SlotEnvelopeCache)
