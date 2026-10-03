require "test_helper"

class BriefingTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @landing = engagements(:landing)
  end

  test "an untouched app has drafts ready and nothing else" do
    counts = Briefing.new(@ted).counts
    assert_equal({ "drafts" => 3 }, counts)
  end

  test "sections reflect what needs a person" do
    Question.create!(user: @ted, text: "?", asked_by: "agent", source: "chat")
    Question.create!(user: users(:sarah), text: "not mine", asked_by: "agent", source: "chat")
    Request.create!(subject: "Help", sender_email: "x@example.org", source: "email")
    agreement_versions(:globex_v1).send!(actor: @ted)
    approve!(@landing)
    @landing.todos.first.update!(status: "blocked")
    @landing.todos.last.update!(due_on: Date.current - 1)
    clients(:acme).commitments.create!(description: "late", due_on: Date.current - 1, source: "t", owner_kind: "us")
    clients(:acme).commitments.create!(description: "soon", due_on: Date.current + 2, source: "t", owner_kind: "client")

    sections = Briefing.new(@ted).sections.to_h { |s| [ s.key, s.items ] }
    assert_equal 1, sections["questions"].size
    assert_equal 1, sections["requests"].size
    assert_equal [ agreement_versions(:globex_v1) ], sections["awaiting_client"]
    assert_equal [ agreement_versions(:retainer_v1) ], sections["drafts"]
    assert_equal [ "late" ], sections["you_promised"].map(&:description)
    assert_equal [ "soon" ], sections["waiting_on_them"].map(&:description)
    assert_equal 1, sections["blocked"].size
    assert_equal 1, sections["overdue_todos"].size
    assert_equal sections.keys.sort, Briefing.new(@ted).counts.keys.sort
  end
end
