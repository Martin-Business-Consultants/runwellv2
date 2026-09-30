require "test_helper"

class CommitmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
  end

  test "index open and resolved" do
    open = clients(:acme).commitments.create!(description: "Open", due_on: Date.current, source: "t")
    done = clients(:acme).commitments.create!(description: "Done", due_on: Date.current, source: "t")
    done.resolve!("done")
    get commitments_path
    assert_equal [ "Open" ], inertia_props["commitments"].map { |c| c["description"] }
    get commitments_path(state: "resolved")
    assert_equal [ "Done" ], inertia_props["commitments"].map { |c| c["description"] }
  end

  test "create on an engagement" do
    assert_difference("Commitment.count") do
      post engagement_commitments_path(@landing), params: { commitment: { description: "Send staging link", due_on: Date.current + 2, owner_kind: "us", user_id: users(:sarah).id } }
    end
    c = Commitment.last
    assert_equal @landing, c.engagement
    assert_equal clients(:acme), c.client
    assert_equal "app", c.source
    assert_equal "commitment.added", c.events.last.kind
  end

  test "create on a client, owned by a contact" do
    post client_commitments_path(clients(:acme)), params: { commitment: { description: "Send logo", due_on: Date.current, owner_kind: "client", contact_id: contacts(:ann).id, source: "call" } }
    c = Commitment.last
    assert_nil c.engagement
    assert_equal "Ann Approver", c.owner_name
    assert_equal "call", c.source
  end

  test "create with errors" do
    post engagement_commitments_path(@landing), params: { commitment: { description: "" } }, headers: { "HTTP_REFERER" => engagement_url(@landing) }
    assert_redirected_to engagement_url(@landing)
    follow_redirect!
    assert inertia_props["errors"]["description"].present?
    assert inertia_props["errors"]["due_on"].present?
  end

  test "resolve" do
    c = clients(:acme).commitments.create!(description: "x", due_on: Date.current, source: "t")
    post resolve_commitment_path(c), params: { resolution: "missed", note: "Slipped" }
    assert_redirected_to commitments_path
    assert_equal [ "missed", "Slipped" ], [ c.reload.resolution, c.resolution_note ]
  end
end
