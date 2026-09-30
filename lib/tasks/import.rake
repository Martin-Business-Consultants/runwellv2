namespace :import do
  desc "Import a Runwell v1 tenant into an empty install: bin/rails \"import:v1[path/to/main.sqlite3,path/to/files]\""
  task :v1, [ :database, :files ] => :environment do |_task, args|
    abort "Usage: bin/rails \"import:v1[path/to/main.sqlite3,path/to/files]\"" if args[:database].blank?
    abort "No such file: #{args[:database]}" unless File.exist?(args[:database])

    Import::V1.new(args[:database], args[:files]).run
  end
end
