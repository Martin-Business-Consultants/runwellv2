require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "approvers are active contacts who can approve" do
    assert_equal [ contacts(:ann) ], clients(:acme).approvers.to_a
    contacts(:ann).archive!
    assert_equal [], clients(:acme).approvers.to_a
  end

  test "name is unique and status known" do
    dup = Client.new(name: "Acme Co", status: "lost")
    assert_not dup.valid?
    assert dup.errors[:name].any?
    assert dup.errors[:status].any?
  end

  test "a client with engagements cannot be destroyed" do
    assert_not clients(:acme).destroy
  end
end
