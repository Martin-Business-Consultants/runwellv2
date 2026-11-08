# Every document shared with the client, in one place (the portal's Documents): on their work, its
# sections, the tasks they can see, and the client itself, newest first.
class Portal::DocumentsController < Portal::BaseController
  agent_tool :portal_documents, on: :index, title: "Documents shared with you",
    description: "Every file shared with you, newest first: its name, size, date, and what it's on."

  def index
    @documents = client.client_documents
  end
end
