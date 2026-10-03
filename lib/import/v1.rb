# Brings one Runwell v1 tenant into an empty v2 install: a copy of the tenant's SQLite file
# (storage/tenants/production/<tenant>/main.sqlite3 in v1) and, optionally, the files it
# attached (v1's storage/<tenant> tree). It reads v1's tables directly and writes through v2's
# models and verbs, so refs, snapshots, approvals, events and the search index come out as if
# the work had been entered here. It prints what it carried over and what it left behind.
#
#   bin/rails "import:v1[path/to/main.sqlite3,path/to/files]"
#
# What maps to what: partners → clients; partner users → contacts; staff → users with their
# passwords; projects, services and work orders → engagements, each with an initial agreement
# (milestones and work order items as scope items) sent and recorded as approved; todos → work;
# tickets → requests; notes, time entries and todo and ticket files; client addresses (custom
# fields) and links (a note). Everything else in v1 (invoices, milestone health, specs,
# questionnaires, daily reports, groups, tags, files whose records v1 no longer has) stays
# behind, and the report lists it.
require "sqlite3"

module Import
  class V1
    SOURCE = "import"
    EVIDENCE = "Imported from Runwell v1"

    TODO_STATUSES = { "open" => "planned", "in_progress" => "in_progress", "in_review" => "in_review",
                      "clarity_needed" => "blocked", "on_hold" => "blocked", "completed" => "done", "cancelled" => "done" }.freeze
    ROLES = { "Admin" => "owner", "Manager" => "manager", "Employee" => "member" }.freeze
    CLIENT_STATUSES = { "Lead" => "dormant", "Active" => "active", "Archived" => "former" }.freeze
    # v1 wrote 0, or an id whose record is gone, where it meant none.
    NO_PROJECT = "(project_id IS NULL OR project_id NOT IN (SELECT id FROM projects))".freeze
    NO_SERVICE = "(service_id IS NULL OR service_id NOT IN (SELECT id FROM services))".freeze

    def initialize(database, files = nil, out: $stdout)
      @db = SQLite3::Database.new(database, readonly: true, results_as_hash: true)
      @files = files.presence
      @out = out
      @users = {}        # v1 user id → User
      @clients = {}      # v1 partner id → Client
      @engagements = {}  # "project:3", "service:1", "work_order:1" → Engagement
      @items = {}        # "milestone:5", "item:2" → ScopeItem
      @todos = {}        # v1 todo id → Todo
      @requests = {}     # v1 ticket id → Request
      @counts = Hash.new(0)
      @skipped = Hash.new { |hash, key| hash[key] = [] }
    end

    def run
      raise "This install already has clients or engagements. Import into an empty database." if Client.exists? || Engagement.exists?

      # History, not news: jobs (mention notifications, file analysis) are held, never run.
      ActiveJob::Base.queue_adapter = :test
      ActionMailer::Base.perform_deliveries = false
      Current.set(source: SOURCE) do
        ActiveRecord::Base.transaction do
          import_users
          import_clients
          import_client_details
          import_engagements
          import_requests
          import_notes
          import_time
          import_branding
          note_what_stays_behind
        end
      end
      # Indexing jobs were held with the rest, so the index is built here, in one pass.
      Searchable.reindex_all
      report
    end

    private

    # --- People --------------------------------------------------------------------------

    # Staff keep their role and password. Client users become contacts below; agent users
    # act through tokens in v2, so they are left behind.
    def import_users
      roles = rows("roles").to_h { [ it["id"], it["name"] ] }
      staff = rows("users").filter_map do |row|
        role = ROLES[roles[row["role_id"]]]
        next if role.nil? || agent?(row)

        [ row, role ]
      end
      staff.sort_by { |row, role| [ role == "owner" ? 0 : 1, row["id"] ] }.each do |row, role|
        user = User.create!(name: row["name"], email_address: row["email_address"], role: role,
                            password_digest: row["password_digest"], created_at: time(row["created_at"]),
                            deactivated_at: (time(row["updated_at"]) unless active?(row)))
        @users[row["id"]] = user
        @counts[:users] += 1
      end
    end

    def actor = @actor ||= User.active.owners.order(:id).first

    def import_clients
      statuses = rows("partner_statuses").to_h { [ it["id"], it["name"] ] }
      rows("partners").each do |row|
        name = row["name"].to_s.squish
        name = "#{name} (#{row["id"]})" if Client.exists?(name: name)
        @clients[row["id"]] = Client.create!(name: name, status: CLIENT_STATUSES.fetch(statuses[row["status_id"]], "active"),
                                             created_at: time(row["created_at"]))
        @counts[:clients] += 1
      end
      import_contacts
    end

    # A v1 client user belongs to any number of partners; v2 gives each contact one client and
    # keeps emails unique, so the same person on a second client is a contact without an email.
    # The client that is still active gets the email.
    def import_contacts
      linked = @db.execute(<<~SQL)
        SELECT pu.partner_id, u.*, ps.name AS partner_status
        FROM partner_users pu
        JOIN users u ON u.id = pu.user_id
        JOIN partners p ON p.id = pu.partner_id
        LEFT JOIN partner_statuses ps ON ps.id = p.status_id
        ORDER BY (ps.name = 'Active') DESC, pu.partner_id, u.id
      SQL
      linked.each do |row|
        next if agent?(row)

        client = @clients[row["partner_id"]] or next
        email = row["email_address"].to_s.strip.downcase.presence
        if email && (other = Contact.find_by(email: email))
          @skipped[:contact_emails] << "#{row["name"]} on #{client.name} keeps no email: #{email} is their contact at #{other.client.name}"
          email = nil
        end
        reachable = email.present? && active?(row)
        client.contacts.create!(name: row["name"], email: email, portal_access: reachable, can_approve: reachable,
                                archived_at: (time(row["updated_at"]) unless active?(row)), created_at: time(row["created_at"]))
        @counts[:contacts] += 1
      end

      linked_ids = linked.map { it["id"] }.uniq
      rows("users").each do |row|
        next if linked_ids.include?(row["id"]) || ROLES.key?(role_name(row)) || agent?(row)

        @skipped[:client_users] << "#{row["name"]} <#{row["email_address"]}> is a client user on no client"
      end
    end

    # --- Engagements ---------------------------------------------------------------------

    def import_engagements
      rows("services").each { import_service(it) }
      rows("projects").each { import_project(it) }
      import_general_work
      rows("work_orders").each { import_work_order(it) }
    end

    def import_project(row)
      client = @clients[row["partner_id"]] or return @skipped[:projects] << "#{row["name"]}: no client"

      engagement = client.engagements.create!(
        label: "project", shape: "fixed", title: row["name"],
        description: rich("Project", row["id"], "description") || row["description"].presence,
        estimate_notes: rich("Project", row["id"], "context") || row["context"].presence,
        created_by: @users[row["user_id"]], created_at: time(row["created_at"]))
      @engagements["project:#{row["id"]}"] = engagement
      @counts[:projects] += 1

      version = engagement.draft_version!(actor: actor)
      version.scope_items.create!(description: row["name"], price_cents: row["total_value"].to_i) if row["total_value"].to_i > 0
      @db.execute("SELECT * FROM milestones WHERE project_id = ? ORDER BY position", [ row["id"] ]).each do |milestone|
        @items["milestone:#{milestone["id"]}"] = version.scope_items.create!(description: milestone["name"], price_cents: 0)
      end
      version.scope_items.create!(description: "#{row["name"]} work", price_cents: 0) if version.scope_items.none?

      agree!(version, todos: todos_where("project_id = ?", row["id"]))
      close!(engagement, "Completed in Runwell v1", at: time(row["completed_at"]) || time(row["updated_at"])) if row["completed"] == 1
    end

    def import_service(row)
      client = @clients[row["partner_id"]] or return @skipped[:services] << "#{row["name"]}: no client"

      engagement = client.engagements.create!(
        label: "service", shape: "recurring", title: row["name"],
        description: rich("Service", row["id"], "description") || row["description"].presence,
        estimate_notes: row["context"].presence,
        created_by: @users[row["user_id"]], created_at: time(row["created_at"]))
      @engagements["service:#{row["id"]}"] = engagement
      @counts[:services] += 1

      version = engagement.draft_version!(actor: actor)
      version.scope_items.create!(description: row["name"], price_cents: row["recurring_value"].to_i)
      agree!(version, todos: todos_where("service_id = ? AND #{NO_PROJECT}", row["id"]))
      close!(engagement, "Ended in Runwell v1", at: time(row["updated_at"])) if row["completed"] == 1 || row["status"] != "active"
    end

    # Work v1 kept on a client with no project or service goes under one "General" engagement
    # per client, so v2 has somewhere to hang it.
    def import_general_work
      todos_where("#{NO_PROJECT} AND #{NO_SERVICE}").group_by { it["partner_id"] }.each do |partner_id, todos|
        client = @clients[partner_id] or next @skipped[:todos] << "#{todos.size} with no client"

        engagement = client.engagements.create!(
          label: "project", shape: "fixed", title: "General",
          description: "<p>Work that had no project in Runwell v1.</p>",
          created_by: actor, created_at: time(todos.map { it["created_at"] }.min))
        @engagements["general:#{partner_id}"] = engagement
        @counts[:general_engagements] += 1

        version = engagement.draft_version!(actor: actor)
        item = version.scope_items.create!(description: "General work", price_cents: 0)
        agree!(version, todos: todos, item: item)
      end
    end

    def import_work_order(row)
      client = @clients[row["partner_id"]] || @engagements["project:#{row["project_id"]}"]&.client
      return @skipped[:work_orders] << "#{row["title"]}: no client" unless client

      engagement = client.engagements.create!(
        label: "work_order", shape: "fixed", title: row["title"],
        description: rich("WorkOrder", row["id"], "description") || row["description"].presence,
        estimate_notes: row["notes"].presence,
        created_by: @users[row["created_by_id"]], created_at: time(row["created_at"]))
      @engagements["work_order:#{row["id"]}"] = engagement
      @counts[:work_orders] += 1

      version = engagement.draft_version!(actor: actor)
      @db.execute("SELECT * FROM work_order_items WHERE work_order_id = ? ORDER BY position", [ row["id"] ]).each do |item|
        description = [ item["name"], plain(item["description"]) ].compact_blank.join(": ")
        estimate = item["estimated_minutes"].to_i > 0 ? "#{(item["estimated_minutes"] / 60.0).round(1)}h" : nil
        @items["item:#{item["id"]}"] = version.scope_items.create!(description: description, price_cents: item["total_cents"].to_i, internal_estimate: estimate)
      end
      version.scope_items.create!(description: row["title"], price_cents: row["quote_amount_cents"].to_i) if version.scope_items.none?

      todos = todos_where("work_order_item_id IN (SELECT id FROM work_order_items WHERE work_order_id = ?)", row["id"])
      if row["approved"] == 1
        agree!(version, todos: todos)
      elsif row["sent_at"].present?
        agree!(version, todos: todos, approve: false)
      else
        todos.each { import_todo(it, engagement) }
      end
      close!(engagement, "Fulfilled in Runwell v1", at: time(row["fulfilled_at"])) if row["fulfilled_at"].present?
    end

    # Send the version, create its work, then record the approval: approving spawns a todo only
    # for items that have none, and those placeholders are removed again.
    def agree!(version, todos:, item: nil, approve: true)
      engagement = version.engagement
      version.send!(actor: actor, source: SOURCE)
      todos.each { import_todo(it, engagement, item: item) }
      return unless approve

      before = engagement.todos.pluck(:id)
      version.decide!(decision: "approved", method: "recorded", approver_name: engagement.client.name,
                      evidence: EVIDENCE, recorded_by: actor, source: SOURCE)
      engagement.todos.where.not(id: before).destroy_all
    end

    def close!(engagement, reason, at:)
      engagement.close!(reason: reason, actor: actor, source: SOURCE)
      engagement.update!(closed_at: at) if at
    end

    # --- Work ----------------------------------------------------------------------------

    def import_todo(row, engagement, item: nil)
      return if @todos.key?(row["id"])

      scope_item = @items["milestone:#{row["milestone_id"]}"] || @items["item:#{row["work_order_item_id"]}"] || item
      scope_item = nil if scope_item && scope_item.engagement != engagement
      owners = todo_owners[row["id"]] || []
      status = TODO_STATUSES.fetch(row["status"], "planned")
      todo = engagement.todos.create!(
        title: row["name"], status: status, scope_item: scope_item,
        description: rich("Todo", row["id"], "description") || row["description"].presence,
        owner: @users[owners.first], due_on: row["due_date"], client_visible: row["client_visible"] == 1,
        completed_at: (time(row["completed_at"]) || time(row["updated_at"]) if status == "done"),
        created_by: @users[row["created_by_id"]], created_at: time(row["created_at"]), updated_at: time(row["updated_at"]))
      @todos[row["id"]] = todo
      @counts[:todos] += 1
      @counts[:todos_cancelled] += 1 if row["status"] == "cancelled"
      @skipped[:extra_assignees] << "#{todo.title}: also #{owners.drop(1).map { user_name(it) }.join(", ")}" if owners.size > 1
      attach_files("Todo", row["id"], todo, client_visible: todo.client_visible?)
    end

    def todos_where(condition, *binds)
      @db.execute("SELECT * FROM todos WHERE #{condition} ORDER BY COALESCE(project_position, service_position, position), id", binds.flatten)
    end

    def todo_owners
      @todo_owners ||= @db.execute("SELECT todo_id, user_id FROM todo_users ORDER BY id")
                          .group_by { it["todo_id"] }.transform_values { |links| links.map { it["user_id"] } }
    end

    # --- Requests, notes, time, files ----------------------------------------------------

    # A ticket that became a todo is a promoted request; a closed one with no todo was dismissed.
    def import_requests
      promoted = @db.execute("SELECT id, originating_ticket_id FROM todos WHERE originating_ticket_id IS NOT NULL ORDER BY id")
                    .group_by { it["originating_ticket_id"] }
      rows("tickets").each do |row|
        request = Request.new(
          client: @clients[row["partner_id"]], subject: row["subject"].presence || "(no subject)",
          body: rich("Ticket", row["id"], "body") || row["body_html"].presence || row["body"].presence,
          sender_name: row["sender_name"], sender_email: row["sender_email"],
          source: row["message_id"].present? ? "email" : "portal",
          received_at: time(row["created_at"]), created_at: time(row["created_at"]))
        if (todo = promoted[row["id"]]&.filter_map { @todos[it["id"]] }&.first)
          request.assign_attributes(status: "promoted", promoted: todo, triaged_by: @users[row["assigned_to_id"]] || actor, triaged_at: todo.created_at)
        elsif row["status"] == "closed"
          request.assign_attributes(status: "dismissed", dismissed_reason: "Closed in Runwell v1", triaged_by: actor, triaged_at: time(row["updated_at"]))
        end
        request.save!
        @requests[row["id"]] = request
        @counts[:requests] += 1
        attach_files("Ticket", row["id"], request, client_visible: true)
      end
    end

    ADDRESS_FIELDS = { "address" => [ "Address", "long_text" ], "phone" => [ "Phone", "text" ], "email" => [ "Email", "text" ] }.freeze

    # v1 kept a client's address (with a phone and an email) and its links (a repository, an admin
    # console) on the client. Addresses become client custom fields, each made only when some
    # client has a value for it; a client's links become a note on it.
    def import_client_details
      details = (table?("partner_addresses") ? rows("partner_addresses") : []).filter_map do |row|
        client = @clients[row["partner_id"]] or next
        locality = [ [ row["city"], row["state"] ].compact_blank.join(", "), row["zip"] ].compact_blank.join(" ")
        values = { "address" => [ row["street"], locality, row["country"] ].compact_blank.join("\n"),
                   "phone" => row["phone"], "email" => row["email"] }.transform_values(&:presence).compact
        [ client, values ] if values.any?
      end

      details.flat_map { it.last.keys }.uniq.each do |key|
        label, kind = ADDRESS_FIELDS.fetch(key)
        CustomField.find_by(model_type: "Client", key: key) || CustomField.create!(model_type: "Client", key: key, label: label, kind: kind)
      end
      details.each do |client, values|
        client.update!(custom_fields: values)
        @counts[:client_addresses] += 1
      end

      (table?("partner_resources") ? rows("partner_resources") : []).group_by { it["partner_id"] }.each do |partner_id, links|
        client = @clients[partner_id] or next
        items = links.map { "<li>#{ERB::Util.html_escape(it["name"])}: <a href=\"#{ERB::Util.html_escape(it["url"])}\">#{ERB::Util.html_escape(it["url"])}</a></li>" }
        client.notes.create!(body: "<p>Links</p><ul>#{items.join}</ul>", kind: "internal", source: SOURCE,
                             occurred_at: time(links.first["created_at"]), created_at: time(links.first["created_at"]))
        @counts[:client_links] += links.size
      end
    end

    def import_notes
      rows("notes").each do |row|
        subject = case row["noteable_type"]
        when "Todo" then @todos[row["noteable_id"]]
        when "Ticket" then @requests[row["noteable_id"]]
        when "Project" then @engagements["project:#{row["noteable_id"]}"]
        when "Partner" then @clients[row["noteable_id"]]
        end
        next @skipped[:notes] << "note #{row["id"]} on #{row["noteable_type"]} #{row["noteable_id"]}, which wasn't imported" unless subject

        body = rich("Note", row["id"], "content") || row["content"].presence
        next @skipped[:notes] << "note #{row["id"]} is empty" unless body

        author = @users[row["user_id"]]
        body = "<p><em>#{ERB::Util.html_escape(user_name(row["user_id"]))} wrote:</em></p>#{body}" if author.nil? && user_name(row["user_id"])
        subject.notes.create!(body: body, kind: row["via_email"] == 1 ? "email" : "internal", author: author, source: SOURCE,
                              occurred_at: time(row["created_at"]), created_at: time(row["created_at"]))
        @counts[:notes] += 1
      end
    end

    # Time entries need the Time tracking plugin installed (Settings > Plugins); without it they're skipped.
    def import_time
      unless defined?(TimeTracking::Entry)
        return @skipped[:time_entries] << "all time entries: install the Time tracking plugin first to bring them in"
      end

      rows("time_entries").each do |row|
        user = @users[row["user_id"]]
        trackable = case row["timeable_type"]
        when "Todo" then @todos[row["timeable_id"]]
        when "Partner" then @clients[row["timeable_id"]]
        when "Project" then @engagements["project:#{row["timeable_id"]}"]
        end
        unless user && trackable && row["minutes"].to_i > 0
          next @skipped[:time_entries] << "entry #{row["id"]}: #{row["minutes"]} min by #{user_name(row["user_id"])} on #{row["timeable_type"]} #{row["timeable_id"]}"
        end

        note = plain(rich("TimeEntry", row["id"], "description") || row["description"])
        TimeTracking::Entry.create!(user: user, trackable: trackable, minutes: row["minutes"], worked_on: time(row["created_at"]).to_date,
                                    note: note&.truncate(255), created_at: time(row["created_at"]))
        @counts[:time_entries] += 1
      end
    end

    def attach_files(record_type, record_id, record, client_visible:)
      attachments(record_type, record_id, "files").each do |file|
        path = blob_path(file["key"]) or next @skipped[:files] << "#{file["filename"]} on #{record_type} #{record_id}: no files directory"
        next @skipped[:files] << "#{file["filename"]} on #{record_type} #{record_id}: missing at #{path}" unless File.exist?(path)

        record.documents.create!(uploaded_by: actor, client_visible: client_visible, created_at: time(file["created_at"]),
                                 file: { io: File.open(path), filename: file["filename"], content_type: file["content_type"] })
        @counts[:files] += 1
      end
    end

    def import_branding
      setting = Setting.current
      %w[logo favicon].each do |name|
        file = attachments("Setting", nil, name).first or next
        path = blob_path(file["key"])
        next unless path && File.exist?(path)

        setting.public_send(name).attach(io: File.open(path), filename: file["filename"], content_type: file["content_type"])
        @counts[:branding] += 1
      end
    end

    # --- Reading v1 ----------------------------------------------------------------------

    def rows(table) = @db.execute("SELECT * FROM #{table} ORDER BY id")

    def rich(record_type, record_id, name)
      @rich ||= @db.execute("SELECT record_type, record_id, name, body FROM action_text_rich_texts")
                   .to_h { [ [ it["record_type"], it["record_id"], it["name"] ], it["body"] ] }
      @rich[[ record_type, record_id, name ]].presence&.then { v2_attachments(it) }
    end

    # v1's rich text carries attachments signed by v1 (gid://todos/…), which v2 can't resolve
    # and would show as ☒. A mention of someone who is staff here becomes a v2 mention; of anyone
    # else (a client user, now a contact), plain "@Name". A pasted image is copied into v2's
    # storage, or noted as gone when v1 no longer had the file.
    ATTACHMENT = %r{<action-text-attachment\b(?:[^>"]|"[^"]*")*>\s*</action-text-attachment>}m

    def v2_attachments(html)
      html.gsub(ATTACHMENT) do |tag|
        gid = v1_gid(tag[/sgid="([^"]+)"/, 1])
        if tag.include?("application/vnd.actiontext.mention")
          v1_id = gid[%r{User/(\d+)}, 1]&.to_i || tag[/data-user-id=\W*(\d+)/, 1]&.to_i
          if (user = @users[v1_id])
            ActionText::Attachment.from_attachable(user).to_html
          else
            label = user_name(v1_id) || tag[/@([^<"\\&]+)/, 1]&.strip || "someone"
            "<strong>@#{ERB::Util.html_escape(label)}</strong>"
          end
        elsif (blob_id = gid[%r{ActiveStorage::Blob/(\d+)}, 1]&.to_i)
          v2_blob(blob_id)&.then { ActionText::Attachment.from_attachable(it).to_html } ||
            "<em>(An image here was removed before the move to Runwell v2.)</em>"
        else
          tag
        end
      end
    end

    def v1_gid(sgid)
      JSON.parse(Base64.decode64(sgid.to_s.split("--").first.to_s.tr("-_", "+/"))).dig("_rails", "data").to_s
    rescue JSON::ParserError
      ""
    end

    def v2_blob(v1_id)
      row = @db.execute("SELECT key, filename, content_type FROM active_storage_blobs WHERE id = ?", [ v1_id ]).first or return
      path = blob_path(row["key"])
      return unless path && File.exist?(path)

      @counts[:inline_images] += 1
      ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: row["filename"], content_type: row["content_type"])
    end

    def attachments(record_type, record_id, name)
      sql = <<~SQL
        SELECT b.key, b.filename, b.content_type, a.created_at
        FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id = a.blob_id
        WHERE a.record_type = ? AND a.name = ? #{"AND a.record_id = ?" if record_id} ORDER BY a.id
      SQL
      @db.execute(sql, [ record_type, name, record_id ].compact)
    end

    # v1's Disk service keeps a tenant's blob "brem/abcd…" at <files>/brem/ab/cd/abcd….
    def blob_path(key)
      return unless @files

      File.join(@files, key.sub(%r{\A([^/]+)/(..)(..)}) { "#{$1}/#{$2}/#{$3}/#{$2}#{$3}" })
    end

    def user_names = @user_names ||= rows("users").to_h { [ it["id"], it["name"] ] }
    def user_name(id) = user_names[id]
    def role_name(row) = (@role_names ||= rows("roles").to_h { [ it["id"], it["name"] ] })[row["role_id"]]
    def agent?(row) = row["agent_owner_id"].present? || row["email_address"].to_s.end_with?("@agents.local")
    def active?(row) = row["active"] == 1 && row["archived"] != 1
    def time(value) = value.presence && Time.find_zone!("UTC").parse(value)
    def plain(html) = html.presence && Rails::HTML5::FullSanitizer.new.sanitize(html).squish.presence

    # --- Report --------------------------------------------------------------------------

    # Files on records the import doesn't bring (or that v1 itself no longer has), and v1 records
    # with no home here, so the report says what stayed behind instead of dropping it silently.
    CARRIED_FILES = %w[Todo Ticket ActionText::RichText Setting ActiveStorage::VariantRecord].freeze

    def note_what_stays_behind
      @db.execute("SELECT record_type, COUNT(*) AS count, SUM(b.byte_size) AS bytes FROM active_storage_attachments a " \
                  "JOIN active_storage_blobs b ON b.id = a.blob_id GROUP BY record_type ORDER BY count DESC").each do |row|
        next if CARRIED_FILES.include?(row["record_type"])

        why = table?(row["record_type"].tableize) ? "nothing to attach them to here" : "their records no longer exist in v1"
        @skipped[:files] << "#{row["count"]} #{row["record_type"]} file(s), #{(row["bytes"].to_i / 1_048_576.0).round(1)} MB: #{why}"
      end
      { "daily_reports" => "daily reports", "documents" => "documents", "invoices" => "invoices", "expenses" => "expenses",
        "specs" => "specs", "weekly_todo_schedules" => "weekly todo schedules" }.each do |table, label|
        next unless table?(table)

        count = @db.get_first_value("SELECT COUNT(*) FROM #{table}").to_i
        @skipped[:records] << "#{count} #{label}: no place for them in Runwell v2" if count > 0
      end
    end

    def table?(name) = @db.get_first_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [ name ]).present?

    def report
      @out.puts "Imported:"
      @counts.sort.each { |key, count| @out.puts "  #{key.to_s.humanize.downcase}: #{count}" }
      @skipped.sort.each do |key, lines|
        @out.puts "\nLeft behind (#{key.to_s.humanize.downcase}, #{lines.size}):"
        lines.first(20).each { @out.puts "  #{it}" }
        @out.puts "  … and #{lines.size - 20} more" if lines.size > 20
      end
      @out.puts "\nCancelled todos were imported as done." if @counts[:todos_cancelled] > 0
      @out.puts "Switch on Time tracking in Settings > Plugins to see the time entries." if @counts[:time_entries] > 0
    end
  end
end
