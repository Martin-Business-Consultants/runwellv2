# Links in the app's navs, marked current anywhere in their section.
module NavigationHelper
  # A section in the left nav: its icon and name, marked as the current page anywhere in its
  # section (/clients, /clients/9…). keys: the go-to chord ("g c"), shown in the link's title.
  def sidenav_link_to(label, path, icon:, keys: nil, current: nil)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/") if current.nil?
    link_to path, class: "sidebar__link", title: (keys ? "#{label} (#{keys})" : label), data: { keys: keys }.compact, aria: { current: ("page" if current) } do
      icon_tag(icon) + tag.span(label, class: "sidebar__label")
    end
  end
end
