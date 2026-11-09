# The grip a client drags a row by to put it in their order of priority (ClientPrioritized). Staff
# viewing the portal as the client (View as) see it too, so they know it's there, but inactive:
# that view changes nothing.
module PortalPrioritiesHelper
  def portal_priority_grip(name)
    if Current.previewing?
      tag.span icon_tag("grip"), class: "portal-sortable__grip portal-sortable__grip--preview",
        title: "#{current_contact.name} drags here to put #{name} in their order. Not while you’re viewing as them."
    else
      tag.span icon_tag("grip"), class: "portal-sortable__grip", draggable: "true", title: "Drag to put #{name} in your order"
    end
  end
end
