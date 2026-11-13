module AvatarsHelper
  def avatar_background_color(user)
    user.avatar_background_color
  end

  # A person's picture, larger (the sidebar's account, a person's page): rune_ui's avatar.
  def avatar_preview_tag(user, hidden_for_screen_reader: false, **options)
    avatar(user.name, url: user_avatar_path(user), size: :lg, class: options.delete(:class))
  end

  def avatar_image_tag(user, **options)
    image_tag user_avatar_path(user), aria: { hidden: "true" }, size: 48, title: user.name, **options
  end

  # A person wherever one appears in the UI: their avatar, with the name as its tooltip and for
  # screen readers. Nobody (no owner, a deleted author) shows `fallback`, if given.
  def person_tag(user, fallback: nil, size: nil)
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) unless user

    avatar(user.display_name, url: user_avatar_path(user), size: size == :large ? :lg : :md, class: "person")
  end

  # A person in a table's cell (Users, and anywhere a row names someone): the same avatar as a
  # task's owner (person_tag), then their name, so every table's rows are the default height.
  def person_cell(user, label: nil, path: nil)
    name = label || user.display_name
    tag.span(class: "person-cell") do
      safe_join([ person_tag(user), (path ? link_to(name, path) : tag.span(name)) ])
    end
  end

  # A client's contacts as overlapping circles of initials (ui :avatar_group): the first `limit`,
  # then "+N" for the rest. Each name is its tooltip and what a screen reader hears.
  def contact_stack(contacts, limit: 3)
    ui :avatar_group, people: contacts.map { { name: it.name } }, max: limit, size: :sm, class: "contact-stack"
  end
end
