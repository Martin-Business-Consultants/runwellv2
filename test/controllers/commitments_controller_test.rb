require "test_helper"

class CommitmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
  end

  test "index open and resolved" do
    clients(:acme).commitments.create!(description: "Open", due_on: Date.current, source: "t")
    done = clients(:acme).commitments.create!(description: "Done", due_on: Date.current, source: "t")
    done.resolve!("done")
    get commitments_path
    assert_response :success
    get commitments_path, as: :json
    assert_equal [ "Open" ], response.parsed_body["commitments"].map { |c| c["description"] }
    get commitments_path(state: "resolved"), as: :json
    assert_equal [ "Done" ], response.parsed_body["commitments"].map { |c| c["description"] }
  end

  test "create on an engagement" do
    assert_difference("Commitment.count") do
      post engagement_commitments_path(@landing), params: { commitment: { description: "Send staging link", due_on: Date.current + 2, owner: "user:#{users(:sarah).id}" } }
    end
    c = Commitment.last
    assert_equal @landing, c.engagement
    assert_equal clients(:acme), c.client
    assert_equal users(:sarah), c.user
    assert_equal "app", c.source
    assert_equal "commitment.added", c.events.last.kind
  end

  test "create on a client, owned by a contact" do
    post client_commitments_path(clients(:acme)), params: { commitment: { description: "Send logo", due_on: Date.current, owner: "contact:#{contacts(:ann).id}", source: "call" } }
    c = Commitment.last
    assert_nil c.engagement
    assert_equal "Ann Approver", c.owner_name
    assert_equal "call", c.source
  end

  test "create with errors" do
    assert_no_difference("Commitment.count") do
      post engagement_commitments_path(@landing), params: { commitment: { description: "" } }, headers: { "HTTP_REFERER" => engagement_url(@landing) }
    end
    assert_redirected_to engagement_url(@landing)
    assert_match(/Description/, flash[:alert])
    assert_match(/Due on/, flash[:alert])
  end

  test "resolve" do
    c = clients(:acme).commitments.create!(description: "x", due_on: Date.current, source: "t")
    post resolve_commitment_path(c), params: { resolution: "missed", note: "Slipped" }
    assert_redirected_to commitments_path
    assert_equal [ "missed", "Slipped" ], [ c.reload.resolution, c.resolution_note ]
  end
end
