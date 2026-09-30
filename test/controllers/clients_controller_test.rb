require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:ted)) }

  test "index" do
    get clients_path
    assert_response :success
    assert_equal %w[Acme\ Co Globex], inertia_props["clients"].map { |c| c["name"] }
  end

  test "show" do
    get client_path(clients(:acme))
    assert_response :success
    assert_equal 2, inertia_props.dig("client", "contacts").size
    assert_equal %w[S-1 WO-1], inertia_props["engagements"].map { |e| e["ref"] }.sort
    assert inertia_props["users"].any?
  end

  test "create" do
    assert_difference("Client.count") do
      post clients_path, params: { client: { name: "Initech", status: "active" } }
    end
    client = Client.last
    assert_redirected_to client_path(client)
    assert_equal "client.created", client.events.last.kind
  end

  test "create with errors" do
    post clients_path, params: { client: { name: "" } }
    assert_redirected_to new_client_path
    follow_redirect!
    assert inertia_props["errors"]["name"].present?
  end

  test "update" do
    patch client_path(clients(:acme)), params: { client: { status: "dormant" } }
    assert_redirected_to client_path(clients(:acme))
    assert_equal "dormant", clients(:acme).reload.status
  end

  test "contacts are added, edited and archived" do
    assert_difference("Contact.count") do
      post client_contacts_path(clients(:acme)), params: { contact: { name: "Cy", email: "cy@acme.example", can_approve: true } }
    end
    contact = Contact.last
    patch contact_path(contact), params: { contact: { role: "CFO" } }
    assert_equal "CFO", contact.reload.role
    delete contact_path(contact)
    assert contact.reload.archived?
    assert_redirected_to client_path(clients(:acme))
  end

  test "contact with a bad email is rejected" do
    post client_contacts_path(clients(:acme)), params: { contact: { name: "Cy", email: "nope" } }
    follow_redirect!
    assert inertia_props["errors"]["email"].present?
  end
end
