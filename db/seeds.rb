# A small agency doing websites, local search (Google Business Profiles, citations,
# reviews) and paid ads, with clients at every stage. Logins: ted@brem.io (owner), Sarah
# (manager) and the members below, all with the password "password". Users are idempotent; the sample
# agency is only created into an empty database (bin/rails db:seed:replant to redo it).
#
# Never in production: db:prepare seeds a database it creates, and a new install starts empty
# so its first visitor signs up as the owner (SignupsController).
return if Rails.env.production?

Current.source = "seed"
# Mentions and their notifications run inline so seeding leaves them in place; their
# emails are not sent.
ActiveJob::Base.queue_adapter = :inline
ActionMailer::Base.perform_deliveries = false

def staff(email, name, role = "member")
  User.find_or_create_by!(email_address: email) { |u| u.name = name; u.role = role; u.password = "password" }
end

ted = staff("ted@brem.io", "Ted Martin", "owner")
sarah = staff("sarah@runwell.app", "Sarah Producer", "manager")
marcus = staff("marcus@runwell.app", "Marcus Webb")
priya = staff("priya@runwell.app", "Priya Nair")
jordan = staff("jordan@runwell.app", "Jordan Blake")

if Client.none?
  today = Date.current

  as = ->(user, &block) { Current.set(session: Session.new(user: user), source: "seed", &block) }
  mention = ->(user) { ActionText::Attachment.from_attachable(user).to_html }

  # A version with items, sent and (optionally) decided. Returns the version.
  agree = lambda do |engagement, items, by:, summary: nil, reason: nil, kind: nil, decision: nil, contact: nil, evidence: nil, comment: nil, sent: true|
    version = engagement.draft_version!(kind: kind, summary: summary, reason: reason, actor: by)
    version.update!(cadence: "monthly") if engagement.recurring? && version.cadence.nil?
    items.each { |description, price, estimate| version.scope_items.create!(description: description, price_cents: price, internal_estimate: estimate) }
    if sent
      version.send!(actor: by, source: "seed")
      if decision
        version.decide!(decision: decision, method: "recorded", contact: contact, evidence: evidence, comment: comment,
                        recorded_by: by, source: "seed")
      end
    end
    version
  end

  work = lambda do |engagement, title, owner: nil, due: nil, status: "planned", description: nil|
    todo = engagement.todos.find_by(title: title) || engagement.todos.create!(title: title, created_by: ted)
    todo.update!(owner: owner, due_on: due, status: status, description: description)
    todo
  end

  note = lambda do |subject, body, author:, kind: "internal", days_ago: 0, source: "app"|
    as.(author) { subject.notes.create!(body: body, kind: kind, author: author, source: source, occurred_at: days_ago.days.ago) }
  end

  # An agency records each client's website. Not every business would, so it's a custom field
  # this install added (Settings > Fields), not a column.
  CustomField.create!(model_type: "Client", label: "Website", kind: "link", listed: true)

  # --- Harbor Dental Group: three offices, new website plus local search -------------------
  harbor = Client.create!(name: "Harbor Dental Group", custom_fields: { "website" => "https://harbordental.example" })
  lena = harbor.contacts.create!(portal_access: true, name: "Dr. Lena Ortiz", role: "Owner", email: "lena@harbordental.example", phone: "555-0142", can_approve: true)
  mia = harbor.contacts.create!(portal_access: true, name: "Mia Chen", role: "Office manager", email: "mia@harbordental.example", phone: "555-0143")

  site = harbor.engagements.create!(label: "project", title: "Website rebuild", created_by: ted,
    description: "<p>A new site for all three offices: service pages, a provider directory, online booking and location pages that support local search.</p>",
    estimate_notes: "<p>Booking widget is their existing Dentrix integration. Budget allows 2 rounds of design revisions.</p>")
  agree.(site, [ [ "Discovery and sitemap", 180_000, "2 days" ], [ "Design: home and 4 templates", 420_000, "6 days" ],
                 [ "Build and content migration", 650_000, "9 days" ], [ "Launch and redirects", 150_000, "2 days" ] ],
    by: ted, summary: "Website rebuild for Harbor Dental's three offices", decision: "approved", contact: lena,
    evidence: "Signed proposal returned by email from Dr. Ortiz")
  work.(site, "Discovery and sitemap", owner: sarah, due: today - 20, status: "done")
  work.(site, "Design: home and 4 templates", owner: marcus, due: today - 2, status: "in_progress",
        description: "<p>Home is approved. Service, provider, location and blog templates in review.</p>")
  work.(site, "Build and content migration", owner: marcus, due: today + 18)
  work.(site, "Launch and redirects", owner: marcus, due: today + 30)
  work.(site, "Collect provider headshots", owner: sarah, due: today - 4, status: "blocked",
        description: "<p>Waiting on Mia to schedule the photographer.</p>")
  agree.(site, [ [ "Spanish-language versions of service pages", 280_000, "4 days" ] ], by: ted,
    kind: "change_order", summary: "Add Spanish service pages",
    reason: "<p>Mia asked for Spanish pages after the design review: about 30% of new patients prefer Spanish.</p>")

  gbp = harbor.engagements.create!(label: "service", shape: "recurring", title: "Local search: 3 offices", created_by: ted,
    description: "<p>Google Business Profile management, citations, review requests and monthly ranking reports for all three offices.</p>")
  agree.(gbp, [ [ "Profile management, 3 locations", 60_000, "4 hrs/mo" ], [ "Citations and review requests", 30_000, "2 hrs/mo" ] ],
    by: priya, summary: "Monthly local search for three offices", decision: "approved", contact: lena, evidence: "Approved on the kickoff call")
  work.(gbp, "Profile management, 3 locations", owner: priya, due: today + 6, status: "in_progress")
  work.(gbp, "Citations and review requests", owner: priya, due: today + 10)
  work.(gbp, "Fix duplicate listing for the Bayview office", owner: priya, due: today - 1, status: "in_progress")

  harbor.commitments.create!(description: "Send provider bios and headshots", due_on: today - 3, owner_kind: "client", contact: mia, engagement: site, source: "seed")
  harbor.commitments.create!(description: "Share the template review link", due_on: today + 2, owner_kind: "us", user: marcus, engagement: site, source: "seed")
  harbor.commitments.create!(description: "Monthly ranking report", due_on: today + 5, owner_kind: "us", user: priya, engagement: gbp, source: "seed")
  as.(sarah) { harbor.commitments.create!(description: "Sitemap sign-off", due_on: today - 15, owner_kind: "client", contact: lena, engagement: site, source: "seed").resolve!("done", note: "Signed off in the discovery meeting", actor: sarah, source: "seed") }

  note.(site, "<p>Design review with Lena and Mia. Home page approved. They want the provider pages to lead with insurance accepted. #{mention.(marcus)} can you add that to the template before Thursday?</p>",
        author: sarah, kind: "meeting", days_ago: 3)
  note.(gbp, "<p>Bayview has a duplicate profile from the previous owner. Filed a merge request with Google. #{mention.(priya)} watch for the verification postcard.</p>",
        author: ted, kind: "internal", days_ago: 1)
  note.(harbor, "<p>Mia called: the photographer can come the week of the 14th. Headshots should follow a few days later.</p>",
        author: sarah, kind: "call", days_ago: 0, source: "phone")

  # --- Summit Roofing: Google Ads, plus storm-season landing pages --------------------------
  summit = Client.create!(name: "Summit Roofing Co", custom_fields: { "website" => "https://summitroofing.example" })
  greg = summit.contacts.create!(portal_access: true, name: "Greg Halvorsen", role: "Owner", email: "greg@summitroofing.example", phone: "555-0171", can_approve: true)
  tasha = summit.contacts.create!(portal_access: true, name: "Tasha Reid", role: "Marketing coordinator", email: "tasha@summitroofing.example")

  ads = summit.engagements.create!(label: "service", shape: "recurring", title: "Google Ads management", created_by: ted,
    description: "<p>Search campaigns for roof repair and replacement across the metro area, with call tracking and a monthly report.</p>",
    estimate_notes: "<p>Management fee only. Ad spend is billed to their card directly.</p>")
  agree.(ads, [ [ "Campaign management", 120_000, "8 hrs/mo" ], [ "Call tracking and reporting", 20_000, "1 hr/mo" ] ],
    by: jordan, summary: "Monthly Google Ads management", decision: "approved", contact: greg, evidence: "Greg replied 'let's go' by email")
  work.(ads, "Campaign management", owner: jordan, due: today + 4, status: "in_progress")
  work.(ads, "Call tracking and reporting", owner: jordan, due: today + 9)
  work.(ads, "Add hail-damage ad group", owner: jordan, due: today + 1)
  agree.(ads, [ [ "Local Services Ads setup and management", 40_000, "2 hrs/mo" ] ], by: jordan, kind: "add_on",
    summary: "Local Services Ads", reason: "<p>Greg wants the Google Guaranteed badge before storm season.</p>",
    decision: "approved", contact: greg, evidence: "Approved on the monthly call")

  storm = summit.engagements.create!(label: "work_order", title: "Storm season landing pages", created_by: ted,
    description: "<p>Three landing pages for hail, wind and emergency tarping, built for the ads campaigns.</p>")
  agree.(storm, [ [ "Copy for 3 landing pages", 90_000, "1.5 days" ], [ "Design and build", 160_000, "2.5 days" ] ],
    by: ted, summary: "Storm season landing pages", sent: false)

  summit.commitments.create!(description: "Send before/after project photos", due_on: today + 6, owner_kind: "client", contact: tasha, engagement: ads, source: "seed")
  summit.commitments.create!(description: "Monthly ads report", due_on: today + 3, owner_kind: "us", user: jordan, engagement: ads, source: "seed")
  note.(ads, "<p>Cost per lead down 18% since we paused broad match. Greg happy. #{mention.(ted)} he asked about storm pages, the draft is ready to send.</p>",
        author: jordan, kind: "call", days_ago: 2, source: "phone")

  # --- Bloom & Vine Florist: a holiday work order waiting on the client ---------------------
  bloom = Client.create!(name: "Bloom & Vine Florist", custom_fields: { "website" => "https://bloomandvine.example" })
  rosa = bloom.contacts.create!(portal_access: true, name: "Rosa Delgado", role: "Owner", email: "rosa@bloomandvine.example", can_approve: true)
  holiday = bloom.engagements.create!(label: "work_order", title: "Holiday ordering updates", created_by: sarah,
    description: "<p>Holiday collections, delivery cut-off banners and a same-day delivery page.</p>")
  version = agree.(holiday, [ [ "Holiday collection pages", 60_000, "1 day" ], [ "Delivery cut-off banners", 25_000, "3 hrs" ] ],
    by: sarah, summary: "Holiday ordering updates")
  version.issue_link!(rosa)
  bloom.commitments.create!(description: "Approve the holiday work order", due_on: today + 1, owner_kind: "client", contact: rosa, engagement: holiday, source: "seed")

  # --- Northside Physical Therapy: local search, and a revision the client pushed back on ---
  northside = Client.create!(name: "Northside Physical Therapy", custom_fields: { "website" => "https://northsidept.example" })
  omar = northside.contacts.create!(portal_access: true, name: "Omar Haddad", role: "Clinic director", email: "omar@northsidept.example", can_approve: true)
  local = northside.engagements.create!(label: "service", shape: "recurring", title: "Local search and reviews", created_by: priya,
    description: "<p>Google Business Profile, review generation and a monthly report for the clinic.</p>")
  agree.(local, [ [ "Profile management", 35_000, "3 hrs/mo" ], [ "Review generation", 15_000, "1 hr/mo" ] ],
    by: priya, summary: "Monthly local search", decision: "approved", contact: omar, evidence: "Signed agreement on file")
  work.(local, "Profile management", owner: priya, due: today + 8, status: "in_progress")
  work.(local, "Review generation", owner: priya, due: today - 5, status: "blocked",
        description: "<p>Their EMR export is needed to send review requests.</p>")
  revision = local.draft_version!(kind: "revision", summary: "Add a second location", actor: priya,
    reason: "<p>Northside is opening a Westgate clinic in the spring.</p>")
  revision.update!(amount_cents: 80_000)
  revision.send!(actor: priya, source: "seed")
  revision.decide!(decision: "changes_requested", method: "recorded", contact: omar, evidence: "Call with Omar",
    comment: "Hold until the Westgate lease is signed.", recorded_by: priya, source: "seed")
  northside.commitments.create!(description: "Send the EMR patient export", due_on: today - 6, owner_kind: "client", contact: omar, engagement: local, source: "seed")
  note.(local, "<p>Omar asked us to hold the second location until the lease is signed. #{mention.(sarah)} can you check back with him next month?</p>",
        author: priya, kind: "call", days_ago: 4, source: "phone")

  # --- Coastal Kitchen & Bath: a prospect with a first draft --------------------------------
  coastal = Client.create!(name: "Coastal Kitchen & Bath", custom_fields: { "website" => "https://coastalkb.example" })
  dana = coastal.contacts.create!(portal_access: true, name: "Dana Whitfield", role: "Co-owner", email: "dana@coastalkb.example", phone: "555-0190", can_approve: true)
  proposal = coastal.engagements.create!(label: "project", title: "New website and portfolio", created_by: ted,
    description: "<p>A portfolio-led site with project galleries, a consultation request form and showroom location pages.</p>",
    estimate_notes: "<p>They have about 60 project photos; galleries need a simple CMS.</p>")
  agree.(proposal, [ [ "Design", 350_000, "5 days" ], [ "Build with project galleries", 480_000, "7 days" ], [ "Launch", 90_000, "1 day" ] ],
    by: ted, summary: "New website and portfolio", sent: false)
  coastal.commitments.create!(description: "Send the proposal", due_on: today + 2, owner_kind: "us", user: ted, engagement: proposal, source: "seed")
  note.(coastal, "<p>Met Dana at the showroom. They lose leads because the current site has no photos. Decision by the end of the month.</p>",
        author: ted, kind: "meeting", days_ago: 6)

  # --- Riverbend Law: a former client with a finished project -------------------------------
  riverbend = Client.create!(name: "Riverbend Law", custom_fields: { "website" => "https://riverbendlaw.example" }, status: "former")
  alan = riverbend.contacts.create!(portal_access: true, name: "Alan Brooks", role: "Managing partner", email: "alan@riverbendlaw.example", can_approve: true)
  done = riverbend.engagements.create!(label: "project", title: "Practice area pages", created_by: ted,
    description: "<p>Twelve practice area pages and attorney bios.</p>")
  agree.(done, [ [ "Practice area pages", 240_000, "4 days" ] ], by: ted, summary: "Practice area pages",
    decision: "approved", contact: alan, evidence: "Signed proposal")
  work.(done, "Practice area pages", owner: marcus, due: today - 60, status: "done")
  as.(ted) { done.close!(reason: "Delivered; client moved in-house", actor: ted, source: "seed") }

  # --- Requests: what came in ----------------------------------------------------------------
  Request.create!(client: harbor, contact: mia, sender_name: mia.name, sender_email: mia.email, source: "portal",
    subject: "Can we add a new-patient special to the home page?", received_at: 5.hours.ago,
    body: "<p>We're running $99 exams for new patients through the end of next month.</p>")
  Request.create!(client: summit, contact: tasha, sender_name: tasha.name, sender_email: tasha.email, source: "email",
    subject: "Pause ads in the north suburbs?", received_at: 1.day.ago,
    body: "<p>Our crew is booked solid up north for two weeks. Can we pause those areas?</p>")
  Request.create!(sender_name: "Kim Park", sender_email: "kim@parkvet.example", source: "phone",
    subject: "Veterinary clinic asking about local search", received_at: 2.days.ago,
    body: "<p>Two-location vet clinic, not showing up in the map pack. Wants a call this week.</p>")
  Request.create!(sender_email: "sales@linkfarm.example", source: "email", subject: "Guest post opportunity",
    received_at: 3.days.ago).dismiss!(reason: "Spam", actor: ted)
  as.(sarah) do
    Request.create!(client: bloom, contact: rosa, sender_name: rosa.name, sender_email: rosa.email, source: "portal",
      subject: "Update our Valentine's hours", received_at: 4.days.ago)
      .promote_to_todo!(engagement: holiday, actor: sarah, owner: sarah, due_on: today + 3)
  end

  # --- Questions for Ted ---------------------------------------------------------------------
  Question.create!(user: ted, subject: site, asked_by: "agent", source: "email: Spanish pages",
    text: "Mia asked for Spanish service pages. Is that in the current scope or a change order?", choices: [ "In scope", "Change order" ])
  Question.create!(user: ted, subject: ads, asked_by: "agent", source: "email: Pause ads",
    text: "Tasha wants to pause the north-suburb campaigns for two weeks. Pause them?", choices: [ "Pause", "Keep running" ])
end

puts "Seeded: #{User.count} users, #{Client.count} clients, #{Engagement.count} engagements, #{Todo.count} todos, " \
     "#{Note.count} notes, #{Mention.count} mentions, #{Request.count} requests"
