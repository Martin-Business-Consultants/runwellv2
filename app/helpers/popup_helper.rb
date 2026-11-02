# Fizzy's popup menu: the dialog a pill or a badge opens below itself (popup.css), with an
# optional title over whatever it holds (a popup__list, a search field, a form). The wrapper
# around trigger and menu carries the `dialog` controller; `fixed: true` also makes it the
# `fixed-popup` target, for menus in rows that a scrolling list would clip.
#
#   <%= popup_menu label: "Status of #{client.name}", title: "Status", fixed: true do %> … <% end %>
module PopupHelper
  def popup_menu(label:, title: nil, fixed: false, &block)
    tag.dialog(class: "margin-block-start-half popup panel flex-column align-start gap-half fill-white shadow txt-small",
               aria: { label: label }, data: { dialog_target: "dialog", fixed_popup_target: ("popup" if fixed) }) do
      safe_join([ (tag.strong(title, class: "popup__title pad-inline-half") if title), capture(&block) ])
    end
  end
end
