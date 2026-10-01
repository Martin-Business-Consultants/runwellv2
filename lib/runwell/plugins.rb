# The core's extension points. A plugin (a Rails engine installed on the server, see
# InstalledPlugins and github.com/Martin-Business-Consultants/runwell-time-tracking) registers
# itself and what it adds here; the core renders whatever is registered for plugins that are
# switched on (Settings > Plugins) and never names a plugin. Plugins start off unless their
# manifest says enabled_by_default: true.
#
#   Runwell::Plugins.register :time_tracking, name: "Time tracking", version: "0.1.0",
#     description: "Timers and logged time on work, with a weekly timesheet."
#   Runwell::Plugins.slot :todo_panel, :time_tracking, "time_tracking/slots/todo_panel"
#   Runwell::Plugins.nav :time_tracking, "Time", -> { time_tracking_timesheet_path }
#   Runwell::Plugins.briefing :time_tracking, "Timers running", partial: "...", items: ->(user) { ... }
#   Runwell::Plugins.permission :time_tracking, :view_everyones_time, name: "See everyone's time", roles: %w[owner manager]
#   Runwell::Plugins.quick_action :time_tracking, label: "Time", icon: "history", partial: "...", types: %w[Client Engagement Todo]
#
# Slots in core views: :nav_actions (no locals; beside the theme toggle), :client_panel (client:),
# :engagement_panel (engagement:), :todo_panel (todo:); in the client portal, :portal_home (client:)
# and :portal_engagement_panel (engagement:). Portal pages come from controllers that inherit
# Portal::BaseController, so they only ever see the signed-in contact's client.
#   Runwell::Plugins.portal_nav :google_ads, "Advertising", -> { google_ads_portal_report_path }
#   Runwell::Plugins.settings :google_ads, "Google Ads", -> { google_ads_settings_path }
#   Runwell::Plugins.nightly :google_ads, -> { GoogleAds::SyncJob.perform_later }
#   Runwell::Plugins.stylesheet :google_ads, "google_ads/charts"   # app/assets/stylesheets in the engine
# Models run load hooks (:runwell_client, :runwell_engagement, :runwell_todo, :runwell_user) so a plugin can
# add associations, and every Event is published as "event.runwell" (event:); a plugin's
# subscriber should check Runwell::Plugins.enabled?(key).
module Runwell
  module Plugins
    Manifest = Struct.new(:key, :name, :version, :description, :author, :enabled_by_default, :requires, :homepage, keyword_init: true) do
      # requires: a Gem::Requirement on the core's version (">= 2.1"), checked against VERSION.
      def compatible? = requires.blank? || Gem::Requirement.new(requires).satisfied_by?(Gem::Version.new(Runwell::VERSION))
    end
    Briefing = Struct.new(:title, :partial, :items, keyword_init: true)

    SLOT_NAMES = { nav_actions: "Nav button", client_panel: "Client panel", engagement_panel: "Engagement panel", todo_panel: "Work panel",
      portal_home: "Portal home", portal_engagement_panel: "Portal engagement panel" }.freeze

    mattr_reader :manifests, default: {}
    mattr_reader :slots, default: Hash.new { |hash, name| hash[name] = {} }
    mattr_reader :nav_items, default: {}
    mattr_reader :briefings, default: {}
    mattr_reader :quick_actions, default: {}
    mattr_reader :permissions, default: Hash.new { |hash, key| hash[key] = {} }
    mattr_reader :portal_nav_items, default: {}
    mattr_reader :settings_pages, default: {}
    mattr_reader :nightly_tasks, default: {}
    mattr_reader :stylesheets, default: Hash.new { |hash, key| hash[key] = [] }
    mattr_reader :agent_briefs, default: {}
    mattr_reader :agent_workflows, default: {}

    class << self
      # Everything is keyed by the plugin, so registering again on a code reload replaces
      # rather than duplicates.
      # enabled_by_default: whether it starts on; plugins are off until the owner switches them
      # on unless they say otherwise. bundled: is ignored (plugins once shipped with the core). requires: the core
      # versions it works with (">= 2.1"); homepage: where to read about it.
      def register(key, name:, version:, description:, author: nil, bundled: nil, enabled_by_default: false, requires: nil, homepage: nil)
        manifests[key] = Manifest.new(key: key, name: name, version: version, description: description, author: author,
          enabled_by_default: enabled_by_default, requires: requires, homepage: homepage)
      end

      def slot(name, key, partial)
        slots[name][key] = partial
      end

      # path: a lambda run in the view, returning nil to leave the link out.
      def nav(key, label, path)
        nav_items[key] = [ label, path ]
      end

      def briefing(key, title, partial:, items:)
        briefings[key] = Briefing.new(title: title, partial: partial, items: items)
      end

      # A link in the client portal's nav, to a page from a Portal::BaseController.
      def portal_nav(key, label, path)
        portal_nav_items[key] = [ label, path ]
      end

      # A tab in Settings, for people who may manage settings (require_permission :manage_settings).
      def settings(key, label, path)
        settings_pages[key] = [ label, path ]
      end

      # Work to run every night (PluginsNightlyJob), e.g. pulling from an outside service.
      def nightly(key, task)
        nightly_tasks[key] = task
      end

      # A section of the brief a local AI gets for a todo (the AI button, the brief_work tool):
      # a lambda taking the todo and the install's base URL, returning Markdown or nil.
      # A workflow an AI harness should know (MCP instructions, `me`, the CLI skill points at it):
      # what to do when a person asks for it, in a few steps naming the plugin's tools.
      def agent_workflow(key, title, text)
        agent_workflows[key] = [ title, text ]
      end

      def agent_brief(key, builder)
        agent_briefs[key] = builder
      end

      # A stylesheet from the plugin's app/assets/stylesheets, linked on every page while it's on.
      def stylesheet(key, name)
        stylesheets[key] |= [ name ]
      end

      # A permission for User#can?, held by the given roles (owner, manager, member). It shows
      # on Settings > People with the core's.
      def permission(key, permission, name:, roles:)
        permissions[key][permission.to_sym] = { name: name, roles: roles }
      end

      # An entry in the quick action tray. The partial renders the form (form_id:),
      # which posts a "record" param ("Client:12") of one of the types. context: maps the
      # record on screen to one of the types, e.g. a scope item to its engagement.
      def quick_action(key, label:, icon:, partial:, types:, title: nil, context: nil)
        quick_actions[key] = QuickAction.new(key: key, label: label, title: title, icon: icon, partial: partial, types: types, context: context)
      end

      def enabled?(key)
        manifest = manifests[key.to_sym] or return false
        Setting.current.plugin_enabled?(key, default: manifest.enabled_by_default)
      end

      def enabled_slots(name) = slots[name].select { |key, _| enabled?(key) }
      def enabled_nav_items = nav_items.select { |key, _| enabled?(key) }
      def enabled_briefings = briefings.select { |key, _| enabled?(key) }
      def enabled_quick_actions = quick_actions.select { |key, _| enabled?(key) }
      def enabled_portal_nav_items = portal_nav_items.select { |key, _| enabled?(key) }
      def enabled_settings_pages = settings_pages.select { |key, _| enabled?(key) }
      def enabled_nightly_tasks = nightly_tasks.select { |key, _| enabled?(key) }
      def enabled_agent_briefs = agent_briefs.select { |key, _| enabled?(key) }
      def enabled_agent_workflows = agent_workflows.select { |key, _| enabled?(key) }
      def enabled_stylesheets = stylesheets.select { |key, _| enabled?(key) }.values.flatten
      def enabled_permissions = permissions.select { |key, _| enabled?(key) }.values.reduce({}, :merge)

      # What a plugin adds, in words, for Settings > Plugins.
      def additions(key)
        slots.filter_map { |name, entries| SLOT_NAMES.fetch(name, name.to_s.humanize) if entries.key?(key) } +
          Array(nav_items[key]&.first&.then { "Nav: #{it}" }) +
          Array(briefings[key]&.title&.then { "Home: #{it}" }) +
          Array(quick_actions[key]&.label&.then { "Quick action: #{it}" }) +
          permissions[key].values.map { "Permission: #{it[:name]}" } +
          Array(portal_nav_items[key]&.first&.then { "Portal: #{it}" }) +
          Array(settings_pages[key]&.first&.then { "Settings: #{it}" }) +
          Array(("Nightly sync" if nightly_tasks.key?(key))) +
          Array(("AI brief" if agent_briefs.key?(key)))
      end
    end
  end
end
