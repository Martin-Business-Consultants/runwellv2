require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
    @request_record = Request.create!(sender_email: "bob@acme.example", subject: "Add a newsletter", body: "please", source: "email: newsletter")
  end

  test "index open and all" do
    Request.create!(sender_email: "x@example.org", subject: "Old", source: "email").dismiss!(reason: "no", actor: users(:ted))
    get requests_path, as: :json
    assert_equal [ "Add a newsletter" ], response.parsed_body["requests"].map { |r| r["subject"] }
    get requests_path(status: "all"), as: :json
    assert_equal 2, response.parsed_body["requests"].size
  end

  test "show" do
    get request_path(@request_record)
    assert_response :success
    assert_select ".record-facts dd", "Bob Requester"
    assert_equal %w[S-1 WO-1], css_select("select[name=engagement_ref]").first.css("option").map { it["value"] }.sort
  end

  test "create" do
    assert_difference("Request.count") do
      post requests_path, params: { request: { subject: "Call notes", body: "Wants a blog", source: "call", client_id: clients(:acme).id } }
    end
    r = Request.last
    assert_redirected_to request_path(r)
    assert_equal "request.received", r.events.last.kind
  end

  test "create with errors" do
    assert_no_difference "Request.count" do
      post requests_path, params: { request: { subject: "" } }
    end
    assert_response :unprocessable_entity
    assert_match(/Subject can.t be blank/, response.body)
  end

  test "promote_engagement" do
    post promote_engagement_request_path(@request_record), params: { label: "work_order", title: "Newsletter" }
    engagement = Engagement.last
    assert_redirected_to engagement_path(engagement)
    assert_equal "Newsletter", engagement.title
    assert_equal "promoted", @request_record.reload.status
  end

  test "promote_engagement for an unmatched request needs a client" do
    stranger = Request.create!(sender_email: "x@example.org", subject: "Site?", source: "email")
    post promote_engagement_request_path(stranger), params: { label: "project" }
    assert_redirected_to request_path(stranger)
    assert_match(/no client/, flash[:alert])
    post promote_engagement_request_path(stranger), params: { label: "project", client_id: clients(:globex).id }
    assert_equal clients(:globex), stranger.reload.client
    assert_equal "promoted", stranger.status
  end

  test "promote_change" do
    approve!(@landing)
    post promote_change_request_path(@request_record), params: { engagement_ref: "WO-1", price_cents: 20_000 }
    assert_redirected_to engagement_path(@landing)
    draft = @landing.reload.draft_version
    assert_equal "change_order", draft.kind
    assert_equal 20_000, draft.scope_items.sole.price_cents
  end

  test "promote_todo" do
    post promote_todo_request_path(@request_record), params: { engagement_ref: "WO-1", owner_id: users(:sarah).id, due_on: Date.current + 1 }
    assert_redirected_to engagement_path(@landing)
    assert_equal users(:sarah), @landing.todos.sole.owner
  end

  test "promote_commitment" do
    post promote_commitment_request_path(@request_record), params: { due_on: Date.current + 1, owner_kind: "client", engagement_ref: "WO-1" }
    assert_redirected_to engagement_path(@landing)
    assert_equal contacts(:bob), Commitment.last.contact
  end

  test "dismiss" do
    post dismiss_request_path(@request_record), params: { reason: "Out of scope" }
    assert_redirected_to requests_path
    assert_equal "dismissed", @request_record.reload.status
    post dismiss_request_path(@request_record)
    assert_match(/already triaged/, flash[:alert])
  end
end
