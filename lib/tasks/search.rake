namespace :search do
  desc "Rebuild the search index from every searchable record"
  task reindex: :environment do
    Searchable.reindex_all(out: $stdout)
  end
end
