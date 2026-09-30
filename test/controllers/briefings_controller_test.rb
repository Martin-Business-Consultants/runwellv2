require "test_helper"

class BriefingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:ted)) }

  test "home greets the signed in user" do
    get root_path
    assert_response :success
    assert_select "h1", /Ted Owner/
  end

  test "requires sign in" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end
end
