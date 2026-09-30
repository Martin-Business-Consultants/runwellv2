json.summary "#{@unread.size} unread"
[ [ :unread, @unread ], [ :read, @read.first(20) ] ].each do |key, notifications|
  json.set! key, notifications do |notification|
    json.id notification.id
    json.summary "#{notification.creator&.display_name} mentioned you"
    json.about agent_ref(notification.source.try(:notifiable_target))
    json.created_at notification.created_at
    json.read notification.read?
  end
end
