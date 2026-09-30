# One index across the app: every searchable record writes a title, its text and the client
# it belongs to, so a single query finds clients, work, requests and notes together.
ActiveSearch.define_index(:searchable, polymorphic: true) do
  text :title
  text :content
  string :client_id
  datetime :created_at
end
