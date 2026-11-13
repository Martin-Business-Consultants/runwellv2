# Links in the app's navs, marked current anywhere in their section.
module NavigationHelper
  # A section in the left nav (runeui's sidebar item): its icon and name, marked as the current
  # page anywhere in its section (/clients, /clients/9…). keys: the go-to chord ("g c"), shown in
  # the link's title, which is also its tooltip while the nav is icons. badge: a count after it.
  def sidenav_link_to(label, path, icon:, keys: nil, current: nil, badge: nil)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/") if current.nil?
    ui :sidebar_item, label: label, href: path, icon: icon_tag(icon), active: current, badge: badge,
      title: (keys ? "#{label} (#{keys})" : label), data: { keys: keys }.compact
  end
end
