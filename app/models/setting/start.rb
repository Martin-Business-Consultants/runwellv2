# Where an install starts (chosen at sign-up, or again in Settings > Names): the words for its
# core things and whether agreements carry prices. Only names and that switch; everything else is
# the same Runwell, and Settings > Names changes any word afterwards.
module Setting::Start
  extend ActiveSupport::Concern

  STARTS = {
    "business" => {
      name: "A business",
      description: "Clients, projects and work orders, with agreements they approve and prices on them.",
      prices: true,
      terminology: {}
    },
    "team" => {
      name: "A team",
      description: "Departments you deliver for, initiatives and their deliverables, tasks. No prices.",
      prices: false,
      terminology: {
        "client" => { "one" => "Department", "other" => "Departments" },
        "engagement" => { "one" => "Initiative", "other" => "Initiatives" },
        "scope_item" => { "one" => "Deliverable", "other" => "Deliverables" },
        "work" => { "one" => "Task", "other" => "Tasks" },
        "labels" => {
          "work_order" => { "enabled" => false },
          "service" => { "one" => "Program", "other" => "Programs", "prefix" => "PG" }
        }
      }
    },
    "personal" => {
      name: "Personal life",
      description: "Areas of life (home, family, a wedding, a trip), plans and their steps, tasks and promises. No prices.",
      prices: false,
      terminology: {
        "client" => { "one" => "Area", "other" => "Areas" },
        "engagement" => { "one" => "Plan", "other" => "Plans" },
        "scope_item" => { "one" => "Step", "other" => "Steps" },
        "work" => { "one" => "Task", "other" => "Tasks" },
        "commitment" => { "one" => "Promise", "other" => "Promises" },
        "labels" => {
          "project" => { "one" => "Plan", "other" => "Plans" },
          "work_order" => { "enabled" => false },
          "service" => { "one" => "Routine", "other" => "Routines", "prefix" => "R" }
        }
      }
    }
  }.freeze

  def apply_start!(key)
    start = STARTS.fetch(key.to_s)
    update!(terminology: start[:terminology].deep_dup, prices: start[:prices])
  end
end
