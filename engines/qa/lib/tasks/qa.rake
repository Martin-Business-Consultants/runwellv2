namespace :qa do
  desc "Load a client's QA checks and source of truth from a YAML file (engines/qa/examples/acme_storage.yml)"
  task :import, [ :path ] => :environment do |_, args|
    path = args[:path].presence or abort "Usage: bin/rails \"qa:import[path/to/checks.yml]\""
    puts Qa::Import.new(YAML.safe_load_file(path, permitted_classes: [ Date ])).call
  end

  desc "Fetch every live check's page now, as the nightly job does"
  task check_pages: :environment do
    Qa::NightlyJob.perform_now
  end
end
