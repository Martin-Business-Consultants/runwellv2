module AvatarsHelper
  def avatar_background_color(user)
    user.avatar_background_color
  end

  def avatar_preview_tag(user, hidden_for_screen_reader: false, **options)
    tag.span class: class_names("avatar", options.delete(:class)),
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil do
      avatar_image_tag(user, **options)
    end
  end

  def avatar_image_tag(user, **options)
    image_tag user_avatar_path(user), aria: { hidden: "true" }, size: 48, title: user.name, **options
  end

  # A person wherever one appears in the UI: their avatar, with the name as its tooltip and for
  # screen readers. Nobody (no owner, a deleted author) shows `fallback`, if given.
  def person_tag(user, fallback: nil, size: nil)
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) unless user

    tag.span class: class_names("person", "person--#{size}" => size), title: user.display_name do
      avatar_image_tag(user, class: "person__avatar", alt: "", title: nil) +
        tag.span(user.display_name, class: "for-screen-reader")
    end
  end
end
