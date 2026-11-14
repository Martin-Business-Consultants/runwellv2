# Fizzy's pagination helper: index lists load their next page as you scroll (geared_pagination,
# the pagination controller and a "Load more…" link that fires when it comes into view).
module PaginationHelper
  # url_for treats these keys as URL-generation control options rather than
  # query parameters. Forwarding them from untrusted request params lets an
  # attacker rewrite the generated pagination path — both `script_name` and
  # `original_script_name` are prepended to the generated script name by
  # RouteSet#url_for before route generation, so either can retarget the link
  # onto an arbitrary same-origin route such as an Active Storage blob-proxy
  # path (HackerOne #3943339). These are the RESERVED_OPTIONS url_for strips
  # before route generation, plus the two control keys it deletes outside that
  # list (_recall, relative_url_root). We forward path parameters
  # (controller/action and route segments like board_id) untouched so url_for
  # can regenerate the current parameterized route; only these control keys are
  # stripped.
  URL_FOR_CONTROL_OPTIONS = %i[
    script_name original_script_name host protocol port subdomain domain
    tld_length trailing_slash only_path relative_url_root anchor params
    _recall
  ].freeze

  def pagination_frame_tag(namespace, page, data: {}, **attributes, &)
    turbo_frame_tag pagination_frame_id_for(namespace, page.number), data: { timeline_target: "frame", **data }, role: "presentation", **attributes, &
  end

  def link_to_next_page(namespace, page, activate_when_observed: false, label: default_pagination_label(activate_when_observed), url: nil, data: {}, **attributes)
    if more_pages_after?(page) && !params[:previous]
      unless activate_when_observed
        attributes[:class] = class_names(attributes[:class], "ui-button pagination-link--manual")
        data = data.merge(variant: "outline", size: "sm")
      end
      pagination_link(namespace, page.number + 1, label: label, activate_when_observed: activate_when_observed, url: url, data: data, **attributes)
    end
  end

  # url: where the pages come from when it isn't this request (a board column rendered on the
  # board's own page loads its next page from the column's address).
  def pagination_link(namespace, page_number, activate_when_observed: false, label: default_pagination_label(activate_when_observed), url_params: {}, url: nil, data: {}, **attributes)
    href = url ? "#{url}#{url.include?("?") ? "&" : "?"}page=#{page_number}" : url_for(forwardable_request_params.merge(page: page_number, **url_params))
    link_to label, href,
      "aria-label": "Load page #{page_number}",
      id: "#{namespace}-pagination-link-#{page_number}",
      class: class_names(attributes.delete(:class), "pagination-link", { "pagination-link--active-when-observed" => activate_when_observed }),
      data: {
        frame: pagination_frame_id_for(namespace, page_number),
        pagination_target: "paginationLink",
        action: ("click->pagination#loadPage:prevent" unless activate_when_observed),
        **data
      },
      **attributes
  end

  # ActiveSearch pages answer next?, geared_pagination's answer before_last?.
  def more_pages_after?(page)
    page.respond_to?(:next?) ? page.next? : page.before_last?
  end

  def pagination_frame_id_for(namespace, page_number)
    "#{namespace}-pagination-contents-#{page_number}"
  end

  def with_automatic_pagination(name, page, next_url: nil, **properties)
    pagination_list name, paginate_on_scroll: true, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page, activate_when_observed: true, url: next_url)
      end)
    end
  end

  # A table page (Runwell's addition): a table's rows sit in <tbody id="<%= pagination_frame_id_for(name, page.number) %>">
  # ending in this "load more" row. The table carries the pagination controller in
  # discard-frame mode, which fetches the next page and swaps this row for that page's rows,
  # since a turbo-frame can't sit among table rows.
  def table_next_page_row(name, page, columns:)
    if more_pages_after?(page) && !params[:previous]
      tag.tr class: "pagination-row", data: { pagination_replace: true } do
        tag.td link_to_next_page(name, page, activate_when_observed: true), colspan: columns
      end
    end
  end

  private
    def forwardable_request_params
      params.permit!.to_h.symbolize_keys.except(*URL_FOR_CONTROL_OPTIONS)
    end

    def pagination_list(name, tag_element: :div, paginate_on_scroll: false, **properties, &block)
      classes = properties.delete(:class)
      properties[:id] ||= "#{name}-pagination-list"
      tag.public_send tag_element,
        class: token_list(name, "pagination-list", classes),
        data: { controller: "pagination", pagination_paginate_on_intersection_value: paginate_on_scroll },
        **properties,
        &block
    end

    def default_pagination_label(activate_when_observed)
      "Load more…"
    end
end
