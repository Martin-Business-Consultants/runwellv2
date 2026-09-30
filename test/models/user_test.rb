require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "needs a name and a known role" do
    user = User.new(email_address: "x@example.com", password: "password", role: "boss")
    assert_not user.valid?
    assert user.errors[:name].any?
    assert user.errors[:role].any?
  end
end
