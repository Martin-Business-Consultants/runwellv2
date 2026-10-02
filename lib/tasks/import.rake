namespace :import do
  desc "Import a Runwell v1 tenant into an empty install: bin/rails \"import:v1[path/to/main.sqlite3,path/to/files]\""
  task :v1, [ :database, :files ] => :environment do |_task, args|
    abort "Usage: bin/rails \"import:v1[path/to/main.sqlite3,path/to/files]\"" if args[:database].blank?
    abort "No such file: #{args[:database]}" unless File.exist?(args[:database])

    Import::V1.new(args[:database], args[:files]).run
  end
end

namespace :import do
  desc "Replace everything in this install with a v1 tenant uploaded as a document: bin/rails \"import:v1_archive[brem-v1-import.tgz,replace]\""
  task :v1_archive, [ :filename, :confirm ] => :environment do |_task, args|
    abort "Usage: bin/rails \"import:v1_archive[file.tgz,replace]\" (replace: this empties the install first)" if args[:filename].blank?
    abort "Pass replace as the second argument: this empties the install (after a backup) before importing." unless args[:confirm] == "replace"

    Import::V1Archive.new(args[:filename]).run
  end
end
