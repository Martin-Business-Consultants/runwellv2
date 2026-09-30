require "test_helper"

class RequestTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @landing = engagements(:landing)
  end

  test "matches the contact and client from the sender email" do
    request = Request.create!(sender_email: "Bob@Acme.example", subject: "Add a newsletter", source: "email: newsletter")
    assert_equal contacts(:bob), request.contact
    assert_equal clients(:acme), request.client
    assert_equal "Bob Requester", request.requester_name
    assert request.open?
  end

  test "a stranger's request is unmatched" do
    request = Request.create!(sender_email: "who@example.org", subject: "Hello", source: "email: hello")
    assert request.unmatched?
    assert_equal "who@example.org", request.requester_name
    assert_raises(ArgumentError) { request.promote_to_engagement!(label: "work_order", actor: @ted) }
  end

  test "promote to a new engagement drafts it with the request as scope" do
    request = Request.create!(sender_email: "bob@acme.example", subject: "New landing page", body: "For summer", source: "chat")
    engagement = request.promote_to_engagement!(label: "work_order", actor: @ted)
    assert_equal "WO-2", engagement.ref
    assert_equal "New landing page", engagement.title
    assert_equal "For summer", engagement.description
    assert_equal [ "New landing page" ], engagement.draft_version.scope_items.map(&:description)
    assert_equal "promoted", request.reload.status
    assert_equal engagement, request.promoted
    assert_equal @ted, request.triaged_by
    assert_equal "request.promoted", request.events.last.kind
  end

  test "promote to change opens a change order when there is no draft" do
    approve!(@landing)
    request = Request.create!(sender_email: "bob@acme.example", subject: "Add a newsletter", source: "chat")
    item = request.promote_to_change!(engagement: @landing, actor: @ted, price_cents: 20_000)
    draft = @landing.reload.draft_version
    assert_equal "change_order", draft.kind
    assert_equal "Add a newsletter", draft.summary
    assert_equal [ item ], draft.scope_items.to_a
    assert_equal 20_000, item.price_cents
    assert_equal draft, request.reload.promoted
  end

  test "promote to change appends to an open draft" do
    request = Request.create!(sender_email: "bob@acme.example", subject: "Add a newsletter", source: "chat")
    request.promote_to_change!(engagement: @landing, actor: @ted)
    assert_equal 3, agreement_versions(:landing_v1).scope_items.count
    assert_equal 1, @landing.agreement_versions.count
  end

  test "promote to work" do
    request = Request.create!(sender_email: "bob@acme.example", subject: "Fix the header", body: "It overlaps", source: "chat")
    todo = request.promote_to_todo!(engagement: @landing, actor: @ted, owner: users(:sarah), due_on: Date.current + 2)
    assert_equal [ "Fix the header", "It overlaps", users(:sarah), Date.current + 2 ], [ todo.title, todo.description, todo.owner, todo.due_on ]
    assert_equal todo, request.reload.promoted
  end

  test "promote to a commitment, ours or theirs" do
    request = Request.create!(sender_email: "bob@acme.example", subject: "Send the copy deck", source: "email: copy")
    commitment = request.promote_to_commitment!(actor: @ted, due_on: Date.current + 3, owner_kind: "client", engagement: @landing)
    assert_equal contacts(:bob), commitment.contact
    assert_equal "Bob Requester", commitment.owner_name
    assert_equal "email: copy", commitment.source
    assert_equal @landing, commitment.engagement
    assert_equal commitment, request.reload.promoted
  end

  test "dismiss" do
    request = Request.create!(sender_email: "who@example.org", subject: "Spam", source: "email")
    request.dismiss!(reason: "Spam", actor: @ted)
    assert_equal "dismissed", request.status
    assert_equal "Spam", request.dismissed_reason
    assert_equal "request.dismissed", request.events.last.kind
  end

  test "a request is triaged once" do
    request = Request.create!(sender_email: "bob@acme.example", subject: "Once", source: "chat")
    request.dismiss!(reason: "no", actor: @ted)
    assert_raises(ArgumentError) { request.dismiss!(reason: "again", actor: @ted) }
    assert_raises(ArgumentError) { request.promote_to_todo!(engagement: @landing, actor: @ted) }
    assert_equal 0, @landing.todos.count
  end
end
