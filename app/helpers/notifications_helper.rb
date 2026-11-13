module NotificationsHelper
  # How many unread the bell's menu lists; past that, its link says "See all new".
  TRAY_SIZE = 6

  # A notification in the bell's menu (notifications/_tray_item): a menu item that's a link, out of
  # the menu's frame to the notification (read on the way to its record).
  def notification_menu_item(notification, &)
    ui_tag(:ui_menu_item, { "as-child": "" }, { class: "ui-item notification notification--item", id: dom_id(notification, :tray), data: { slot: "menu-link-item" } },
      link_to(notification_path(notification), class: "notification__link", data: { turbo_frame: "_top" }, &))
  end

  # A notification on /notifications: the link, then the toggle that reads or unreads it in place.
  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: class_names("notification", unread: !notification.read?),
        data: { filter_target: "item", badge_target: "unread" } do
      link_to(notification_path(notification), class: "notification__link", data: { turbo_frame: "_top", action: "badge#update" }, &) +
        notification_toggle_read_button(notification, url: notification_reading_path(notification))
    end
  end

  def notification_toggle_read_button(notification, url:)
    label = notification.read? ? "Mark as unread" : "Mark as read"
    button_to url, method: (notification.read? ? :delete : :post), class: "ui-button notification__toggle", title: label,
        aria: { label: label }, data: { variant: "ghost", size: "icon-sm", action: "badge#update" }, form: { class: "notification__toggle-form" } do
      safe_join([ icon_tag(notification.read? ? "unseen" : "check"),
                  (tag.span(notification.unread_count, class: "notification__count") if !notification.read? && notification.unread_count > 1) ].compact)
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
