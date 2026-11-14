# What a client moves a row by to put it in their order of priority (ClientPrioritized): a grip to
# drag, which the arrow keys also move once it's focused, and on a touch screen a pair of buttons
# in its place (the drag-and-drop controller's moveUp / moveDown). Staff viewing the portal as the
# client (View as) see the grip too, so they know it's there, but inactive: that view changes nothing.
module PortalPrioritiesHelper
  def portal_priority_grip(name)
    if Current.previewing?
      return tag.span icon_tag("grip"), class: "portal-sortable__grip portal-sortable__grip--preview",
        title: "#{current_contact.name} drags here to put #{name} in their order. Not while you’re viewing as them."
    end

    grip = tag.span icon_tag("grip"), class: "portal-sortable__grip", draggable: "true", tabindex: 0, role: "button",
      title: "Drag to put #{name} in your order, or press ↑ or ↓", aria: { label: "Move #{name}: press up or down" },
      data: { action: "keydown.up->drag-and-drop#moveUp keydown.down->drag-and-drop#moveDown" }
    moves = tag.span class: "portal-sortable__moves" do
      safe_join([
        ui(:button, variant: :ghost, size: :icon_xs, class: "portal-sortable__move", content: icon_tag("arrow-up"), title: "Move #{name} up", aria: { label: "Move #{name} up" }, data: { action: "drag-and-drop#moveUp" }),
        ui(:button, variant: :ghost, size: :icon_xs, class: "portal-sortable__move portal-sortable__move--down", content: icon_tag("arrow-up"), title: "Move #{name} down", aria: { label: "Move #{name} down" }, data: { action: "drag-and-drop#moveDown" })
      ])
    end
    grip + moves
  end
end
