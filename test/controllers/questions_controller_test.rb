require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @question = Question.create!(user: users(:ted), text: "?", asked_by: "agent", source: "chat", subject: engagements(:landing))
  end

  test "answer" do
    post answer_question_path(@question), params: { answer: "Yes" }
    assert_redirected_to root_path
    assert_equal "Yes", @question.reload.answer
  end

  test "dismiss" do
    post dismiss_question_path(@question)
    assert_redirected_to root_path
    assert @question.reload.dismissed_at
  end

  test "only the person asked can answer" do
    sign_out
    sign_in_as(users(:sarah))
    post answer_question_path(@question), params: { answer: "Yes" }
    assert_response :not_found
  end
end
