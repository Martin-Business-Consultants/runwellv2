module NotificationsHelper
  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item tray__item--notification", data: { navigable_list_target: "item", filter_target: "item" } do
      link_to(notification_path(notification),
        class: [ "card card--notification", { "unread": !notification.read? } ],
        data: { turbo_frame: "_top", badge_target: "unread", action: "badge#update dialog#close" },
        &)
    end
  end

  def notification_toggle_read_button(notification, url:)
    if notification.read?
      button_to url,
          method: :delete,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: "Mark as unread",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("unseen"))
      end
    else
      button_to url,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: "Mark as read",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("remove"))
        concat(tag.span(notification.unread_count, class: "badge-count")) if notification.unread_count > 1
      end
    end
  end

  # What a notification is about, in the card header's id and name slots.
  def notification_target_label(record)
    case record
    when Engagement then [ record.ref, record.client.name ]
    when Todo, AgreementVersion, ScopeItem then [ record.engagement.ref, record.engagement.title ]
    when Request then [ "Request", record.subject ]
    when Note then notification_target_label(record.subject)
    when Client then [ "Client", record.name ]
    else [ record.model_name.human, record.try(:search_title) ]
    end
  end
end
