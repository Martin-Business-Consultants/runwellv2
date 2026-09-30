json.merge! agent_ref(commitment)
json.extract! commitment, :description, :due_on, :owner, :source, :resolution, :resolution_note
json.owner_name commitment.owner_name
json.open commitment.open?
json.overdue commitment.overdue?
json.client agent_ref(commitment.client)
json.engagement agent_ref(commitment.engagement)
