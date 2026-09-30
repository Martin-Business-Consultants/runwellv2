namespace :search do
  desc "Rebuild the search index from every searchable record"
  task reindex: :environment do
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_documents")
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_documents_fts")

    [ Client, Contact, Engagement, Request, Todo, Commitment, Note, Document ].each do |model|
      model.find_each(&:reindex)
      puts "Reindexed #{model.count} #{model.model_name.human.pluralize.downcase}"
    end
  end
end
