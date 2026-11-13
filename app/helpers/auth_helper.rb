module AuthHelper
  # A way in's one card (sign in, a link, a code, a new password, sign-up, an invitation, a consent,
  # the portal's sign in): runeui's card naming the step in its centred header, the block as its
  # fields and buttons. shake: a refused try shakes it once (public.css).
  def auth_card(title:, hint: nil, shake: false, &body)
    ui :card, title: tag.h1(title, class: "auth__title"), description: hint.presence,
      class: class_names("auth__card", "auth__card--shake": shake), content: (capture(&body).presence if body)
  end
end
