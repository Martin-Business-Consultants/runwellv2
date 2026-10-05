require "test_helper"

class EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
  end

  test "index filters by state and label" do
    @landing.close!
    get engagements_path(state: "open"), as: :json
    assert_equal %w[P-1 S-1], engagement_refs.sort
    get engagements_path(state: "closed"), as: :json
    assert_equal %w[WO-1], engagement_refs
    get engagements_path(state: "all", label: "service"), as: :json
    assert_equal %w[S-1], engagement_refs
  end

  test "show" do
    approve!(@landing)
    get engagement_path(@landing)
    assert_response :success
    assert_select "h1.page-title", "WO-1 Spring landing page"
    assert_select ".record-meta", /Approved/
    assert_select ".record-meta strong", "$4,000.00"
    assert_select ".record-tabs__tab", text: /Agreement\s*1/
    assert_select "#work .work-group > ul > li", 2
    assert_select ".scope-nav__item", 3

    get engagement_path(@landing, item: scope_items(:design).id)
    assert_select ".work-focus__title", "Design and copy"
    assert_select "#work .work-group > ul > li", 1
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
    assert_select "select[name='engagement[label]'] option[selected][value=project]"
    assert_select "select[name='engagement[client_id]'] option[selected][value='#{clients(:acme).id}']"
  end

  test "create drafts an engagement with an empty first version" do
    assert_difference([ "Engagement.count", "AgreementVersion.count" ]) do
      post engagements_path, params: { engagement: { client_id: clients(:acme).id, label: "project", title: "Rebrand", estimate_notes: "2 weeks" } }
    end
    engagement = Engagement.last
    assert_redirected_to engagement_path(engagement)
    assert_equal "P-2", engagement.ref
    assert engagement.draft_version.present?
    assert_equal "engagement.created", engagement.events.first.kind
  end

  test "create with errors" do
    assert_no_difference "Engagement.count" do
      post engagements_path, params: { engagement: { client_id: clients(:acme).id, label: "project", title: "" } }
    end
    assert_response :unprocessable_entity
    assert_match(/Title can.t be blank/, response.body)
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

  private
    def engagement_refs = response.parsed_body["engagements"].map { |e| e["ref"] }
end
