# Every document shared with the client, in one place (the portal's Documents): on their work, its
# sections, the tasks they can see, and the client itself, newest first.
class Portal::DocumentsController < Portal::BaseController
  agent_tool :portal_documents, on: :index, title: "Documents shared with you",
    description: "Every file shared with you, newest first: its name, size, date, and what it's on."

  # A plugin's page standing in for this one (Runwell::Plugins.portal_nav replaces: :documents) is
  # where a person goes instead; an agent still gets the list.
  def index
    if request.format.html? && (replacement = Runwell::Plugins.portal_replacement(:documents)) && (url = helpers.instance_exec(&replacement.last))
      return redirect_to(url)
    end

    @documents = client.client_documents
  end
end
