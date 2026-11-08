module NotificationsHelper
  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item tray__item--notification notification", data: { navigable_list_target: "item", filter_target: "item" } do
      link_to(notification_path(notification),
        class: class_names("list-row notification__link", unread: !notification.read?),
        data: { turbo_frame: "_top", badge_target: "unread", action: "badge#update dialog#close" },
        &)
    end
  end

  def notification_toggle_read_button(notification, url:)
    if notification.read?
      button_to url,
          method: :delete,
          class: "notification__toggle icon-button",
          title: "Mark as unread",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("unseen"))
      end
    else
      button_to url,
          class: "notification__toggle icon-button",
          title: "Mark as read",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("check"))
        concat(tag.span(notification.unread_count, class: "count notification__count")) if notification.unread_count > 1
      end
    end
  end

  # What a notification is about: its ref and name, on the line under it.
  def notification_target_label(record)
    case record
    when Work then [ record.title, record.client.name ]
    when Task then record.work ? [ record.work.title, record.client&.name ] : [ Setting.current.term(:task), record.client&.name || record.title ]
    when ScopeItem then [ record.work.title, record.description ]
    when Note then notification_target_label(record.subject)
    when Client then [ "Client", record.name ]
    else [ record.model_name.human, record.try(:search_title) ]
    end
  end
end
