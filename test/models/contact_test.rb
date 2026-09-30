require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "email is normalised, optional and unique" do
    c = clients(:acme).contacts.create!(name: "Cy", email: " CY@Acme.example ")
    assert_equal "cy@acme.example", c.email
    assert clients(:acme).contacts.create!(name: "No email").email.nil?
    assert_not clients(:globex).contacts.new(name: "Dup", email: "ann@acme.example").valid?
  end

  test "portal login token round-trips and expires" do
    token = contacts(:ann).generate_token_for(:portal_login)
    assert_equal contacts(:ann), Contact.find_by_token_for(:portal_login, token)
    travel 2.hours do
      assert_nil Contact.find_by_token_for(:portal_login, token)
    end
  end
end
