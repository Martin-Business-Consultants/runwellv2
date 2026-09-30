require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:ted)) }

  test "create on an engagement" do
    engagement = engagements(:landing)
    assert_difference("Note.count") do
      post notes_path, params: { subject_type: "Engagement", subject_id: engagement.id, note: { body: "Kickoff call", kind: "call" } },
                       headers: { "HTTP_REFERER" => engagement_url(engagement) }
    end
    note = engagement.notes.sole
    assert_equal [ users(:ted), "app", "call" ], [ note.author, note.source, note.kind ]
    assert_equal "note.added", engagement.events.last.kind
    assert_redirected_to engagement_url(engagement)
  end

  test "create with errors" do
    post notes_path, params: { subject_type: "Client", subject_id: clients(:acme).id, note: { body: "" } }
    follow_redirect!
    assert inertia_props["errors"]["body"].present?
  end

  test "refuses unknown subjects" do
    post notes_path, params: { subject_type: "User", subject_id: users(:ted).id, note: { body: "x" } }
    assert_response :bad_request
  end
end
