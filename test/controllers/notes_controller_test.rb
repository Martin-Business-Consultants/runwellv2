require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:ted)) }

  test "create on a piece of work" do
    work = works(:landing)
    assert_difference("Note.count") do
      post notes_path, params: { record: "Work:#{work.id}", note: { body: "Kickoff call", kind: "call" } },
                       headers: { "HTTP_REFERER" => work_url(work) }
    end
    note = work.notes.sole
    assert_equal [ users(:ted), "app", "call" ], [ note.author, note.source, note.kind ]
    assert_equal "note.added", work.events.last.kind
    assert_redirected_to work_url(work)
  end

  test "create with errors" do
    assert_no_difference("Note.count") do
      post notes_path, params: { record: "Client:#{clients(:acme).id}", note: { body: "" } }
    end
    assert_redirected_to client_path(clients(:acme))
    assert_match(/Body/, flash[:alert])
  end

  test "refuses unknown subjects" do
    post notes_path, params: { record: "User:#{users(:ted).id}", note: { body: "x" } }
    assert_response :bad_request
  end
end
