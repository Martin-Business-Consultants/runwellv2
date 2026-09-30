module TodosBoardHelper
  # Fizzy's card_article_tag for a todo. The card color comes from its column's CSS, since
  # views never carry inline styles.
  def todo_article_tag(todo, data: {}, **options, &block)
    tag.article id: dom_id(todo, :article), class: token_list(options.delete(:class), "card--active": todo.status == "in_progress"),
      data: data, **options, &block
  end

  def todo_column_color(status)
    { "in_progress" => "var(--color-card-4)", "in_review" => "var(--color-card-6)", "blocked" => "var(--color-card-8)" }.fetch(status)
  end

  def todo_board_filters
    request.query_parameters.slice("owner", "engagement")
  end
end
