require "test_helper"

class BriefingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:ted)) }

  test "home says when nothing needs the person" do
    get root_path
    assert_response :success
    assert_select ".home-empty", /Nothing needs you/
  end

  test "requires sign in" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end
end
