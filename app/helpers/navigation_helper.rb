# Links in the app's navs, marked current anywhere in their section.
module NavigationHelper
  # A top nav link, marked as the current page anywhere in its section (/clients, /clients/9…).
  # keys: the go-to chord for the keyboard controller ("g c"), shown in the link's title.
  def nav_link_to(label, path, keys: nil, **options)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/")
    options = options.merge(title: "#{label} (#{keys})", data: (options[:data] || {}).merge(keys: keys)) if keys
    link_to label, path, **options, aria: { current: ("page" if current) }
  end

  # A section in the left nav: its icon and name, marked current like nav_link_to.
  def sidenav_link_to(label, path, icon:, keys: nil, current: nil)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/") if current.nil?
    link_to path, class: "sidebar__link", title: (keys ? "#{label} (#{keys})" : label), data: { keys: keys }.compact, aria: { current: ("page" if current) } do
      icon_tag(icon) + tag.span(label, class: "sidebar__label")
    end
  end
end
