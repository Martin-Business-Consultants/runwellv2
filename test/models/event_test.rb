require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "append-only" do
    client = clients(:acme)
    event = client.record_event!("client.created", actor: users(:ted), source: "chat", payload: { via: "test" })
    assert_equal "Ted Owner", event.actor_name
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(kind: "changed") }
    assert_not event.destroy
    assert Event.exists?(event.id)
  end

  test "an agent actor is a label" do
    event = clients(:acme).record_event!("note.added", actor: nil, actor_label: "morning-sweep", source: "playbook")
    assert_equal "morning-sweep", event.actor_name
  end

  test "needs a source and a kind" do
    event = Event.new(subject: clients(:acme), occurred_at: Time.current)
    assert_not event.valid?
    assert event.errors[:kind].any?
    assert event.errors[:source].any?
  end
end
