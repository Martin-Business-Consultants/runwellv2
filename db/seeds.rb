# A sample business: a small studio doing websites, local search (Google Business Profiles, citations,
# reviews) and paid ads, with clients at every stage. Logins: ted@brem.io (owner), Sarah
# (manager) and the members below, all with the password "password". Users are idempotent; the sample
# sample is only created into an empty database (bin/rails db:seed:replant to redo it).
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

  # An engagement's sections, by name.
  sections = ->(engagement, names) { names.each { engagement.scope_items.create!(description: it) } }

  # Work on an engagement, under the section of the same name when there is one.
  work = lambda do |engagement, title, owner: nil, due: nil, status: "planned", description: nil|
    engagement.todos.create!(title: title, created_by: ted, owner: owner, due_on: due, status: status, description: description,
                             scope_item: engagement.scope_items.find_by(description: title))
  end

  note = lambda do |subject, body, author:, kind: "internal", days_ago: 0, source: "app"|
    as.(author) { subject.notes.create!(body: body, kind: kind, author: author, source: source, occurred_at: days_ago.days.ago) }
  end

  # This studio records each client's website. Not every business would, so it's a custom field
  # this install added (Settings > Fields), not a column.
  CustomField.create!(model_type: "Client", label: "Website", kind: "link", listed: true)

  # --- Harbor Dental Group: three offices, new website plus local search -------------------
  harbor = Client.create!(name: "Harbor Dental Group", custom_fields: { "website" => "https://harbordental.example" })
  lena = harbor.contacts.create!(portal_access: true, name: "Dr. Lena Ortiz", role: "Owner", email: "lena@harbordental.example", phone: "555-0142", can_approve: true)
  mia = harbor.contacts.create!(portal_access: true, name: "Mia Chen", role: "Office manager", email: "mia@harbordental.example", phone: "555-0143")

  site = harbor.engagements.create!(label: "project", title: "Website rebuild", created_by: ted,
    description: "<p>A new site for all three offices: service pages, a provider directory, online booking and location pages that support local search.</p>",
    estimate_notes: "<p>Booking widget is their existing Dentrix integration. Budget allows 2 rounds of design revisions.</p>")
  sections.(site, [ "Discovery and sitemap", "Design: home and 4 templates", "Build and content migration", "Launch and redirects" ])
  work.(site, "Discovery and sitemap", owner: sarah, due: today - 20, status: "done")
  work.(site, "Design: home and 4 templates", owner: marcus, due: today - 2, status: "in_progress",
        description: "<p>Home is approved. Service, provider, location and blog templates in review.</p>")
  work.(site, "Build and content migration", owner: marcus, due: today + 18)
  work.(site, "Launch and redirects", owner: marcus, due: today + 30)
  work.(site, "Collect provider headshots", owner: sarah, due: today - 4, status: "blocked",
        description: "<p>Waiting on Mia to schedule the photographer.</p>")
  sections.(site, [ "Spanish-language versions of service pages" ])

  gbp = harbor.engagements.create!(label: "service", shape: "recurring", title: "Local search: 3 offices", created_by: ted,
    description: "<p>Google Business Profile management, citations, review requests and monthly ranking reports for all three offices.</p>")
  sections.(gbp, [ "Profile management, 3 locations", "Citations and review requests" ])
  work.(gbp, "Profile management, 3 locations", owner: priya, due: today + 6, status: "in_progress")
  work.(gbp, "Citations and review requests", owner: priya, due: today + 10)
  work.(gbp, "Fix duplicate listing for the Bayview office", owner: priya, due: today - 1, status: "in_progress")

  # Promises are work with a date, owned by whoever it's assigned to.
  work.(site, "Share the template review link", owner: marcus, due: today + 2)
  work.(gbp, "Monthly ranking report", owner: priya, due: today + 5)

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
  sections.(ads, [ "Campaign management", "Call tracking and reporting" ])
  work.(ads, "Campaign management", owner: jordan, due: today + 4, status: "in_progress")
  work.(ads, "Call tracking and reporting", owner: jordan, due: today + 9)
  work.(ads, "Add hail-damage ad group", owner: jordan, due: today + 1)
  sections.(ads, [ "Local Services Ads setup and management" ])

  storm = summit.engagements.create!(label: "work_order", title: "Storm season landing pages", created_by: ted,
    description: "<p>Three landing pages for hail, wind and emergency tarping, built for the ads campaigns.</p>")
  sections.(storm, [ "Copy for 3 landing pages", "Design and build" ])

  work.(ads, "Monthly ads report", owner: jordan, due: today + 3)
  note.(ads, "<p>Cost per lead down 18% since we paused broad match. Greg happy. #{mention.(ted)} he asked about storm pages, the plan is ready to walk him through.</p>",
        author: jordan, kind: "call", days_ago: 2, source: "phone")

  # --- Bloom & Vine Florist: a holiday work order ----------------------------------------------
  bloom = Client.create!(name: "Bloom & Vine Florist", custom_fields: { "website" => "https://bloomandvine.example" })
  rosa = bloom.contacts.create!(portal_access: true, name: "Rosa Delgado", role: "Owner", email: "rosa@bloomandvine.example", can_approve: true)
  holiday = bloom.engagements.create!(label: "work_order", title: "Holiday ordering updates", created_by: sarah,
    description: "<p>Holiday collections, delivery cut-off banners and a same-day delivery page.</p>")
  sections.(holiday, [ "Holiday collection pages", "Delivery cut-off banners" ])

  # --- Northside Physical Therapy: local search, with a second location on hold --------------
  northside = Client.create!(name: "Northside Physical Therapy", custom_fields: { "website" => "https://northsidept.example" })
  omar = northside.contacts.create!(portal_access: true, name: "Omar Haddad", role: "Clinic director", email: "omar@northsidept.example", can_approve: true)
  local = northside.engagements.create!(label: "service", shape: "recurring", title: "Local search and reviews", created_by: priya,
    description: "<p>Google Business Profile, review generation and a monthly report for the clinic.</p>")
  sections.(local, [ "Profile management", "Review generation" ])
  work.(local, "Profile management", owner: priya, due: today + 8, status: "in_progress")
  work.(local, "Review generation", owner: priya, due: today - 5, status: "blocked",
        description: "<p>Their EMR export is needed to send review requests.</p>")
  note.(local, "<p>Omar asked us to hold the second location until the lease is signed. #{mention.(sarah)} can you check back with him next month?</p>",
        author: priya, kind: "call", days_ago: 4, source: "phone")

  # --- Coastal Kitchen & Bath: a prospect --------------------------------------------------
  coastal = Client.create!(name: "Coastal Kitchen & Bath", custom_fields: { "website" => "https://coastalkb.example" })
  dana = coastal.contacts.create!(portal_access: true, name: "Dana Whitfield", role: "Co-owner", email: "dana@coastalkb.example", phone: "555-0190", can_approve: true)
  proposal = coastal.engagements.create!(label: "project", title: "New website and portfolio", created_by: ted,
    description: "<p>A portfolio-led site with project galleries, a consultation request form and showroom location pages.</p>",
    estimate_notes: "<p>They have about 60 project photos; galleries need a simple CMS.</p>")
  sections.(proposal, [ "Design", "Build with project galleries", "Launch" ])
  # Work straight on the client, not on its engagement.
  coastal.todos.create!(title: "Send the proposal", owner: ted, due_on: today + 2, created_by: ted)
  note.(coastal, "<p>Met Dana at the showroom. They lose leads because the current site has no photos. Decision by the end of the month.</p>",
        author: ted, kind: "meeting", days_ago: 6)

  # --- Riverbend Law: a former client with a finished project -------------------------------
  riverbend = Client.create!(name: "Riverbend Law", custom_fields: { "website" => "https://riverbendlaw.example" }, status: "former")
  alan = riverbend.contacts.create!(portal_access: true, name: "Alan Brooks", role: "Managing partner", email: "alan@riverbendlaw.example", can_approve: true)
  done = riverbend.engagements.create!(label: "project", title: "Practice area pages", created_by: ted,
    description: "<p>Twelve practice area pages and attorney bios.</p>")
  sections.(done, [ "Practice area pages" ])
  work.(done, "Practice area pages", owner: marcus, due: today - 60, status: "done")
  as.(ted) { done.close!(reason: "Delivered; client moved in-house", actor: ted, source: "seed") }

  # --- Requests: what came in, work nobody has taken on yet -----------------------------------
  harbor.todos.create!(contact: mia, sender_name: mia.name, sender_email: mia.email, source: "portal",
    title: "Can we add a new-patient special to the home page?", created_at: 5.hours.ago,
    description: "<p>We're running $99 exams for new patients through the end of next month.</p>")
  summit.todos.create!(contact: tasha, sender_name: tasha.name, sender_email: tasha.email, source: "email",
    title: "Pause ads in the north suburbs?", created_at: 1.day.ago,
    description: "<p>Our crew is booked solid up north for two weeks. Can we pause those areas?</p>")
  Todo.create!(sender_name: "Kim Park", sender_email: "kim@parkvet.example", source: "phone",
    title: "Veterinary clinic asking about local search", created_at: 2.days.ago,
    description: "<p>Two-location vet clinic, not showing up in the map pack. Wants a call this week.</p>")
  # One a client asked for that someone has taken on.
  holiday.todos.create!(contact: rosa, sender_name: rosa.name, sender_email: rosa.email, source: "portal",
    title: "Update our Valentine's hours", owner: sarah, due_on: today + 3, created_by: sarah, created_at: 4.days.ago)
end

# Indexing runs in jobs; build the index now so search works straight after seeding.
Searchable.reindex_all

puts "Seeded: #{User.count} users, #{Client.count} clients, #{Engagement.count} engagements, #{Todo.count} todos, " \
     "#{Note.count} notes, #{Mention.count} mentions, #{Todo.requests.count} requests"
