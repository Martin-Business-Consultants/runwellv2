require "test_helper"

class BriefingTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @landing = engagements(:landing)
  end

  test "an untouched app needs nothing from a person" do
    assert Briefing.new(@ted).empty?
  end

  test "sections are the person's own work and what waits on them" do
    work_per_section!(@landing)
    @landing.todos.first.update!(status: "blocked", owner: @ted)
    @landing.todos.last.update!(due_on: Date.current - 1, owner: @ted)
    clients(:acme).todos.create!(title: "soon", due_on: Date.current + 2, owner: @ted)
    clients(:acme).todos.create!(title: "not mine", due_on: Date.current + 2, owner: users(:sarah))

    sections = Briefing.new(@ted).sections.to_h { |s| [ s.key, s.items ] }
    assert_equal [ "soon" ], sections["week"].map(&:title)
    assert_equal 1, sections["blocked"].size
    assert_equal 1, sections["overdue"].size
    assert_not sections.key?("requests")
  end
end
