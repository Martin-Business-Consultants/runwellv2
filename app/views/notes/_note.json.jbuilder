json.merge! agent_ref(note)
json.extract! note, :kind, :source, :occurred_at
json.author agent_user(note.author)
json.body agent_text(note.body)
