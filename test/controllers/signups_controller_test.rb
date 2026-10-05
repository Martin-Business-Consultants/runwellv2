require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    remove_users
    get new_signup_path
    assert_response :success
  end

  test "create signs the new user in" do
    remove_users
    assert_difference -> { User.people.count } do
      post signup_path, params: { signup: { name: "Nina New", email_address: "Nina@Example.com", password: "secret123" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert User.find_by!(email_address: "nina@example.com")
  end

  test "the first user to sign up is the owner" do
    remove_users
    post signup_path, params: { signup: { name: "Olive First", email_address: "olive@example.com", password: "secret123" } }
    assert User.find_by!(email_address: "olive@example.com").owner?
  end

  test "create with errors re-renders the form" do
    remove_users
    assert_no_difference -> { User.count } do
      post signup_path, params: { signup: { name: "", email_address: "not an address", password: "secret123" } }
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
  end

  test "signed in users go home" do
    sign_in_as users(:ted)
    get new_signup_path
    assert_redirected_to root_path
  end

  private
    def remove_users
      ActiveRecord::Base.connection.disable_referential_integrity { User.delete_all }
    end
end
