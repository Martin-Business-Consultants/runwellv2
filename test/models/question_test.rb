require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  setup do
    @question = Question.create!(user: users(:ted), text: "In scope?", choices: [ "Yes", "No" ], asked_by: "agent", source: "chat", subject: engagements(:landing))
  end

  test "answering closes it and records an event on the subject" do
    @question.answer!("No")
    assert_equal "No", @question.answer
    assert_not @question.open?
    assert_equal({ "question" => "In scope?", "answer" => "No" }, engagements(:landing).events.last.payload)
    assert_raises(ArgumentError) { @question.answer!("Yes") }
  end

  test "dismissing closes it" do
    @question.dismiss!
    assert_not @question.open?
    assert_equal [], Question.unanswered.to_a
    assert_raises(ArgumentError) { @question.dismiss! }
  end
end
