require "test_helper"

class EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
  end

  test "index filters by state and label" do
    @landing.close!
    get engagements_path
    assert_equal %w[P-1 S-1], inertia_props["engagements"].map { |e| e["ref"] }.sort
    get engagements_path(state: "closed")
    assert_equal %w[WO-1], inertia_props["engagements"].map { |e| e["ref"] }
    get engagements_path(label: "service")
    assert_equal %w[S-1], inertia_props["engagements"].map { |e| e["ref"] }
  end

  test "show" do
    approve!(@landing)
    get engagement_path(@landing)
    assert_response :success
    props = inertia_props
    assert_equal "approved", props.dig("engagement", "state")
    assert_equal 400_000, props.dig("engagement", "agreed_amount_cents")
    assert_equal 1, props.dig("engagement", "versions").size
    assert_equal 2, props["todos"].size
    assert_equal 1, props["billable_items"].size
    assert_equal 1, props["contacts"].count { |c| c["can_approve"] }
  end

  test "show by ref is case-insensitive and 404s otherwise" do
    get engagement_path("wo-1")
    assert_response :success
    get engagement_path("WO-99")
    assert_response :not_found
  end

  test "new" do
    get new_engagement_path(client_id: clients(:acme).id, label: "project")
    assert_response :success
    assert_equal "project", inertia_props.dig("engagement", "label")
    assert_equal clients(:acme).id, inertia_props.dig("engagement", "client_id")
  end

  test "create drafts an engagement with an empty first version" do
    assert_difference([ "Engagement.count", "AgreementVersion.count" ]) do
      post client_engagements_path(clients(:acme)), params: { engagement: { label: "project", title: "Rebrand", estimate_notes: "2 weeks" } }
    end
    engagement = Engagement.last
    assert_redirected_to engagement_path(engagement)
    assert_equal "P-2", engagement.ref
    assert engagement.draft_version.present?
    assert_equal "engagement.created", engagement.events.first.kind
  end

  test "create with errors" do
    post client_engagements_path(clients(:acme)), params: { engagement: { label: "project", title: "" } }
    assert_redirected_to new_engagement_path(client_id: clients(:acme).id)
    follow_redirect!
    assert inertia_props["errors"]["title"].present?
  end

  test "update" do
    patch engagement_path(@landing), params: { engagement: { title: "Spring page", client_id: clients(:globex).id } }
    assert_redirected_to engagement_path(@landing)
    assert_equal "Spring page", @landing.reload.title
    assert_equal clients(:acme), @landing.client, "client cannot be moved"
  end

  test "close" do
    post close_engagement_path(@landing), params: { reason: "Delivered" }
    assert_redirected_to engagement_path(@landing)
    assert @landing.reload.closed?
    assert_equal "Delivered", @landing.close_reason
  end
end
