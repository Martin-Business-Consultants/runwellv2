module Reporting
  # Server-drawn SVG for the reports: paired bars (billed beside collected) per month, with a
  # <title> on each bar for hover. Amounts are integer cents; labels are dollars.
  module ChartsHelper
    WIDTH = 640
    HEIGHT = 190
    TOP = 18
    BOTTOM = 22

    def report_month_chart(points)
      max = points.flat_map { [ it[:billed], it[:collected] ] }.max.to_i
      plot = HEIGHT - TOP - BOTTOM
      step = WIDTH.to_f / [ points.size, 1 ].max
      bar = step * 0.34
      bars = points.each_with_index.flat_map do |point, index|
        [ [ :billed, 0 ], [ :collected, 1 ] ].map do |series, offset|
          height = max.positive? ? point[series] * plot.to_f / max : 0
          x = index * step + step * 0.14 + offset * bar
          tag.rect(x: x.round(1), y: (TOP + plot - height).round(1), width: (bar * 0.92).round(1), height: height.round(1),
            class: "report-chart__bar report-chart__bar--#{series}") { tag.title("#{point[:full_label]} #{series}: #{money point[series]}") }
        end
      end
      labels = points.each_with_index.map { |point, index| tag.text(point[:label], x: (index * step + step / 2).round(1), y: HEIGHT - 6, class: "report-chart__label") }

      tag.svg(viewBox: "0 0 #{WIDTH} #{HEIGHT}", class: "report-chart", role: "img", "aria-label": "Billed and collected by month") do
        safe_join([
          tag.line(x1: 0, y1: TOP, x2: WIDTH, y2: TOP, class: "report-chart__grid"),
          tag.line(x1: 0, y1: HEIGHT - BOTTOM, x2: WIDTH, y2: HEIGHT - BOTTOM, class: "report-chart__axis"),
          tag.text(money(max), x: 0, y: TOP - 5, class: "report-chart__label report-chart__label--start"),
          *bars, *labels
        ])
      end
    end

    # A share of a whole as a thin bar, for aging and coverage.
    def report_share(cents, total)
      share = total.to_i.positive? ? (cents * 100.0 / total).round : 0
      tag.span(class: "report-share", role: "img", "aria-label": "#{share}%") do
        tag.svg(viewBox: "0 0 100 6", preserveAspectRatio: "none", class: "report-share__track") { tag.rect(x: 0, y: 0, width: share, height: 6, class: "report-share__fill") }
      end
    end
  end
end
