# The core's extension points. A plugin (a Rails engine installed on the server, see
# InstalledPlugins and github.com/Martin-Business-Consultants/runwell-time-tracking) registers
# itself and what it adds here; the core renders whatever is registered for plugins that are
# switched on (Settings > Plugins) and never names a plugin. Every plugin starts off (a manifest's
# enabled_by_default is ignored since 5.0), and an install has none until one is added by its
# GitHub repository.
#
#   Runwell::Plugins.register :time_tracking, name: "Time tracking", version: "0.1.0",
#     description: "Timers and logged time on work, with a weekly timesheet."
#   Runwell::Plugins.slot :task_panel, :time_tracking, "time_tracking/slots/task_panel"
#   Runwell::Plugins.nav :time_tracking, "Time", -> { time_tracking_timesheet_path }
#   Runwell::Plugins.permission :time_tracking, :view_everyones_time, name: "See everyone's time", roles: %w[owner manager]
#   Runwell::Plugins.quick_action :time_tracking, label: "Time", icon: "history", partial: "...", types: %w[Client Work Task]
#
# Slots in core views: :nav_actions (no locals; beside the theme toggle), :client_panel (client:),
# :work_panel (work:), :task_panel (task:), :email_inbound (no locals; Settings > Email,
# where requests' mail comes in), :client_aside
# (client:), :work_aside (work:, its sidebar), :work_meta (work:, the line under
# its title: a status badge or a short fact), :task_aside (task:, a piece of work's sidebar),
# :scope_item_aside (scope_item:), :task_notice (task:, under a task's title on its page and in its
# side panel: a short note) and :note_row (note:), inside each row; in the
# client portal, :portal_home (client:), :portal_dashboard (client:, contact:, beside the work on its
# first page: a dashboard for the client, which the core doesn't draw), :portal_task (task:,
# contact:, in a shared task's side sheet, above its files and discussion),
# :portal_work_panel (work:) and :portal_actions (contact:, the header's buttons). Portal pages come from controllers that inherit
# Portal::BaseController, so they only ever see the signed-in contact's client.
#   Runwell::Plugins.portal_nav :google_ads, "Advertising", -> { google_ads_portal_report_path }
#   Runwell::Plugins.settings :google_ads, "Google Ads", -> { google_ads_settings_path }
#   Runwell::Plugins.nightly :google_ads, -> { GoogleAds::SyncJob.perform_later }
#   Runwell::Plugins.stylesheet :google_ads, "google_ads/charts"   # app/assets/stylesheets in the engine
# Models run load hooks (:runwell_client, :runwell_work, :runwell_task, :runwell_user) so a plugin can
# add associations, and every Event is published as "event.runwell" (event:); a plugin's
# subscriber should check Runwell::Plugins.enabled?(key).
module Runwell
  module Plugins
    Manifest = Struct.new(:key, :name, :version, :description, :author, :enabled_by_default, :requires, :homepage, keyword_init: true) do
      # requires: a Gem::Requirement on the core's version (">= 2.1"), checked against VERSION.
      def compatible? = requires.blank? || Gem::Requirement.new(requires).satisfied_by?(Gem::Version.new(Runwell::VERSION))
    end
    # A question the Ask panel offers in one click (types: the records it suits, nil for any page).
    AiPrompt = Struct.new(:label, :types, keyword_init: true) do
      def applies_to?(subject) = types.nil? || types.map(&:to_s).include?(subject.class.name)
    end

    # A key a plugin answers to, listed on the ? sheet (the control itself declares data-keys).
    Shortcut = Struct.new(:keys, :description, keyword_init: true)

    SLOT_NAMES = { nav_actions: "Nav button", client_panel: "Client panel", work_panel: "Work panel", task_panel: "Work panel",
      email_inbound: "Settings › Email, requests by email", portal_home: "Portal home", portal_work_panel: "Portal work panel",
      client_aside: "Client sidebar", work_aside: "Work sidebar", work_meta: "Work title line",
      task_aside: "Work sidebar", scope_item_aside: "Section sidebar", note_row: "Notes", portal_actions: "Portal header",
      task_notice: "Task notice", portal_dashboard: "Portal dashboard", portal_task: "Portal task" }.freeze

    # Something dated a plugin offers to calendars (Runwell::Plugins.dates): a meeting, a renewal,
    # a deadline of its own. label says what kind ("Meeting"), path where it opens, people who it's
    # about (Users), plugin which plugin it came from (filled in by the core).
    Dated = Data.define(:date, :title, :label, :path, :people, :plugin) do
      def initialize(date:, title:, label:, path: nil, people: [], plugin: nil) = super
    end

    mattr_reader :manifests, default: {}
    mattr_reader :slots, default: Hash.new { |hash, name| hash[name] = {} }
    mattr_reader :nav_items, default: {}
    mattr_reader :quick_actions, default: {}
    mattr_reader :permissions, default: Hash.new { |hash, key| hash[key] = {} }
    mattr_reader :portal_nav_items, default: {}
    # The core's portal pages a plugin's page may stand in for (portal_nav replaces:).
    REPLACEABLE_PORTAL_PAGES = %i[documents].freeze
    mattr_reader :settings_pages, default: {}
    mattr_reader :nightly_tasks, default: {}
    mattr_reader :stylesheets, default: Hash.new { |hash, key| hash[key] = [] }
    mattr_reader :agent_briefs, default: {}
    mattr_reader :agent_workflows, default: {}
    mattr_reader :ai_prompts, default: Hash.new { |hash, key| hash[key] = [] }
    mattr_reader :shortcuts, default: Hash.new { |hash, key| hash[key] = [] }
    mattr_reader :date_sources, default: {}
    mattr_reader :away_sources, default: {}
    mattr_reader :notice_rules, default: {}

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
      # icon: any core icon name (icon_tag), "grid" when none is given.
      def nav(key, label, path, icon: nil)
        nav_items[key] = [ label, path, icon ]
      end

      # Removed in 5.0 with the home briefing. Kept as a no-op only so a plugin that still calls it
      # boots; it is not part of the contract (docs/plugin-contract.md, Removed).
      def briefing(key, *, **)
        Rails.logger.warn("[Runwell] #{key} calls Runwell::Plugins.briefing, removed in 5.0; it does nothing")
      end

      # A link in the client portal's nav, to a page from a Portal::BaseController. replaces: one of
      # the core's own portal pages (REPLACEABLE_PORTAL_PAGES) the plugin's page stands in for: its
      # link takes that one's place in the nav, and the core's page sends people to it.
      def portal_nav(key, label, path, replaces: nil)
        raise ArgumentError, "#{key} can't replace the portal's #{replaces}" if replaces && !replaces.in?(REPLACEABLE_PORTAL_PAGES)

        portal_nav_items[key] = [ label, path, replaces ]
      end

      # The switched-on plugin's portal link standing in for one of the core's portal pages, or nil:
      # [label, path].
      def portal_replacement(page) = enabled_portal_nav_items.values.find { it[2] == page }&.first(2)

      # A tab in Settings, for people who may manage settings (require_permission :manage_settings).
      def settings(key, label, path)
        settings_pages[key] = [ label, path ]
      end

      # Work to run every night (PluginsNightlyJob), e.g. pulling from an outside service.
      def nightly(key, task)
        nightly_tasks[key] = task
      end

      # A section of the brief a local AI gets for a task (the AI button, the brief_task tool):
      # a lambda taking the task and the install's base URL, returning Markdown or nil.
      # A workflow an AI harness should know (MCP instructions, `me`, the CLI skill points at it):
      # what to do when a person asks for it, in a few steps naming the plugin's tools.
      def agent_workflow(key, title, text)
        agent_workflows[key] = [ title, text ]
      end

      def agent_brief(key, builder)
        agent_briefs[key] = builder
      end

      # Dated things for a calendar: ->(range, viewer) { [ Runwell::Plugins::Dated.new(date:, title:, label:, path:, people:) ] },
      # only what the viewer (a User) may see, inside the range of dates.
      def dates(key, source)
        date_sources[key] = source
      end

      # Who's away when, for pickers that put people on things (the task owner picker marks someone
      # "Out" on a task's due date): ->(range) { { user_id => [dates], everyone: [dates] } }.
      def away(key, source)
        away_sources[key] = source
      end

      # Every switched-on plugin's away days in a range, merged: { user_id => Set of dates }, with
      # :everyone for days off for all (a holiday). A source that fails is reported and left out.
      def away_between(range)
        enabled_away_sources.each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |(key, source), away|
          source.call(range).to_h.each { |who, dates| away[who].merge(Array(dates).select { range.cover?(it) }) }
        rescue StandardError => error
          Rails.error.report(error, context: { plugin: key, extension: :away })
        end
      end

      # Every switched-on plugin's dated things in a range, as the viewer may see them, each marked
      # with its plugin. A source that fails is reported and left out, so one plugin can't empty a
      # calendar.
      def dates_between(range, viewer:)
        enabled_date_sources.flat_map do |key, source|
          Array(source.call(range, viewer)).select { range.cover?(it.date) }.map { it.with(plugin: key) }
        rescue StandardError => error
          Rails.error.report(error, context: { plugin: key, extension: :dates })
          []
        end
      end

      # A question for the in-app AI's Ask panel, offered on the given record types (Client,
      # Work, Task, ScopeItem) or, with none, on every page.
      def ai_prompt(key, label, types: nil)
        ai_prompts[key] |= [ AiPrompt.new(label: label, types: types) ]
      end

      # A key on the ? sheet: "i", "Ask AI about what's on screen". The plugin's control declares
      # it (data-keys="i"), which is what makes it work; this only lists it.
      def shortcut(key, keys, description)
        shortcuts[key] |= [ Shortcut.new(keys: keys, description: description) ]
      end

      # A stylesheet from the plugin's app/assets/stylesheets, linked on every page while it's on.
      def stylesheet(key, name)
        stylesheets[key] |= [ name ]
      end

      # A permission for User#can?, held by the given roles (owner, manager, member). It shows
      # on Users with the core's.
      def permission(key, permission, name:, roles:)
        permissions[key][permission.to_sym] = { name: name, roles: roles }
      end

      # Who hears about what passes between a client and the team (Notice): a plugin choosing, per
      # client, among the people who could. client: for the client's people (kinds
      # Notice::CLIENT_KINDS), team: for the team's (Notice::TEAM_KINDS); each a lambda
      #   ->(kind:, client:, record:, usual:, everyone:) { recipients }
      # given who would usually hear and everyone who could, returning who does. client is nil for
      # a request emailed by someone not on file.
      def notices(key, client: nil, team: nil)
        notice_rules[key] = { client: client, team: team }
      end

      # Each switched-on plugin's say in turn, starting from the usual recipients; never anyone
      # outside `everyone`. A rule that fails is reported and skipped.
      def notice_recipients(side, kind:, client:, record:, usual:, everyone:)
        enabled_notice_rules.reduce(usual) do |recipients, (key, rules)|
          rule = rules[side]
          next recipients unless rule

          Array(rule.call(kind: kind, client: client, record: record, usual: recipients, everyone: everyone)) & everyone
        rescue StandardError => error
          Rails.error.report(error, context: { plugin: key, extension: :notices })
          recipients
        end
      end

      # An entry in the quick action tray. The partial renders the form (form_id:),
      # which posts a "record" param ("Client:12") of one of the types. context: maps the
      # record on screen to one of the types, e.g. a scope item to its work.
      def quick_action(key, label:, icon:, partial:, types:, title: nil, context: nil)
        quick_actions[key] = QuickAction.new(key: key, label: label, title: title, icon: icon, partial: partial, types: types, context: context)
      end

      def enabled?(key)
        return false unless manifests.key?(key.to_sym)
        # Every plugin starts off, whatever its manifest says, until the owner switches it on.
        Setting.current.plugin_enabled?(key, default: false)
      end

      def enabled_slots(name) = slots[name].select { |key, _| enabled?(key) }
      def enabled_nav_items = nav_items.select { |key, _| enabled?(key) }
      def enabled_quick_actions = quick_actions.select { |key, _| enabled?(key) }
      def enabled_portal_nav_items = portal_nav_items.select { |key, _| enabled?(key) }
      def enabled_settings_pages = settings_pages.select { |key, _| enabled?(key) }
      def enabled_nightly_tasks = nightly_tasks.select { |key, _| enabled?(key) }
      def enabled_agent_briefs = agent_briefs.select { |key, _| enabled?(key) }
      def enabled_date_sources = date_sources.select { |key, _| enabled?(key) }
      def enabled_away_sources = away_sources.select { |key, _| enabled?(key) }
      def enabled_notice_rules = notice_rules.select { |key, _| enabled?(key) }
      def enabled_agent_workflows = agent_workflows.select { |key, _| enabled?(key) }
      def enabled_ai_prompts = ai_prompts.select { |key, _| enabled?(key) }.values.flatten.map { [ nil, it ] }
      def enabled_shortcuts = shortcuts.select { |key, _| enabled?(key) }.values.flatten
      def enabled_stylesheets = stylesheets.select { |key, _| enabled?(key) }.values.flatten
      def enabled_permissions = permissions.select { |key, _| enabled?(key) }.values.reduce({}, :merge)

      # What a plugin adds, in words, for Settings > Plugins.
      def additions(key)
        slots.filter_map { |name, entries| SLOT_NAMES.fetch(name, name.to_s.humanize) if entries.key?(key) } +
          Array(nav_items[key]&.first&.then { "Nav: #{it}" }) +
          Array(quick_actions[key]&.label&.then { "Quick action: #{it}" }) +
          permissions[key].values.map { "Permission: #{it[:name]}" } +
          Array(portal_nav_items[key]&.first&.then { "Portal: #{it}" }) +
          Array(settings_pages[key]&.first&.then { "Settings: #{it}" }) +
          Array(("Nightly sync" if nightly_tasks.key?(key))) +
          Array(("AI brief" if agent_briefs.key?(key))) +
          Array(("Calendar dates" if date_sources.key?(key))) +
          Array(("Who's away" if away_sources.key?(key)))
      end
    end
  end
end
