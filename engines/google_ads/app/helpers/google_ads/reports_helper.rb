module GoogleAds
  # Figures and charts for the advertising report. Charts are SVG drawn on the server: bars for
  # amounts, lines for rates, one axis per measure, and a <title> on every point for hover.
  # Undefined figures (nil) render as an em dash, never as zero.
  module ReportsHelper
    CHART_WIDTH = 640
    CHART_HEIGHT = 180
    CHART_TOP = 18
    CHART_BOTTOM = 22

    def ads_figure(value, format)
      return "—" if value.nil?

      case format
      when :money then money(value)
      when :percent then number_to_percentage(value * 100, precision: 1)
      when :decimal then number_with_delimiter(value.round(1))
      else number_with_delimiter(value)
      end
    end

    # "▲ 12% on last month", green when it's better for the client, red when worse.
    # neutral: a change that is neither good nor bad in itself (spend).
    def ads_change(report, key, lower_is_better: false, neutral: false)
      change = report.change_in(key)
      return tag.span("No comparison", class: "txt-x-small txt-subtle") if change.nil?

      better = lower_is_better ? change.negative? : change.positive?
      tone = change.zero? || neutral ? "txt-subtle" : (better ? "txt-positive" : "txt-negative")
      arrow = change.zero? ? "" : (change.positive? ? "▲ " : "▼ ")
      tag.span "#{arrow}#{number_to_percentage(change.abs * 100, precision: 0)} #{report.comparison_label}", class: "txt-x-small #{tone}"
    end

    # Bars for an amount across days or months.
    def ads_bar_chart(points, value:, format:, name:)
      max = points.map { it[value].to_f }.max.to_f
      plot = CHART_HEIGHT - CHART_TOP - CHART_BOTTOM
      step = CHART_WIDTH.to_f / [ points.size, 1 ].max
      bar = [ step * 0.7, 1 ].max

      bars = points.each_with_index.map do |point, index|
        amount = point[value].to_f
        height = max.positive? ? (amount / max * plot) : 0
        x = index * step + (step - bar) / 2
        tag.rect(x: x.round(1), y: (CHART_TOP + plot - height).round(1), width: bar.round(1), height: height.round(1),
          class: class_names("ads-chart__bar", "ads-chart__bar--current": point[:current])) do
          tag.title("#{point[:full_label]}: #{ads_figure(point[value], format)}")
        end
      end

      ads_chart_frame(points, step, name: name, top_label: ads_figure(max, format), contents: bars)
    end

    # Lines for rates that share an axis (percentages). A day with no figure breaks the line.
    def ads_line_chart(points, series:, name:)
      values = series.flat_map { |key, _| points.filter_map { it[key] } }
      max = [ values.max.to_f, 0.0001 ].max
      plot = CHART_HEIGHT - CHART_TOP - CHART_BOTTOM
      step = CHART_WIDTH.to_f / [ points.size, 1 ].max

      lines = series.flat_map do |key, tone|
        segments = points.each_with_index.chunk_while { |(a, _), (b, _)| a[key] && b[key] }.select { |run| run.first.first[key] }
        segments.map do |run|
          coordinates = run.map { |point, index| "#{(index * step + step / 2).round(1)},#{(CHART_TOP + plot - point[key] / max * plot).round(1)}" }
          if run.size == 1
            x, y = coordinates.first.split(",")
            tag.circle(cx: x, cy: y, r: 2.5, class: "ads-chart__dot ads-chart__dot--#{tone}") { tag.title("#{run.first.first[:full_label]}: #{ads_figure(run.first.first[key], :percent)}") }
          else
            tag.polyline(points: coordinates.join(" "), class: "ads-chart__line ads-chart__line--#{tone}")
          end
        end
      end

      ads_chart_frame(points, step, name: name, top_label: ads_figure(max, :percent), contents: lines)
    end

    private
      def ads_chart_frame(points, step, name:, top_label:, contents:)
        baseline = CHART_HEIGHT - CHART_BOTTOM
        every = [ (points.size / 8.0).ceil, 1 ].max
        labels = points.each_with_index.filter_map do |point, index|
          next unless (index % every).zero? || index == points.size - 1

          tag.text(point[:label], x: (index * step + step / 2).round(1), y: CHART_HEIGHT - 6, class: "ads-chart__label")
        end

        tag.svg(viewBox: "0 0 #{CHART_WIDTH} #{CHART_HEIGHT}", class: "ads-chart", role: "img", "aria-label": name) do
          safe_join([
            tag.line(x1: 0, y1: CHART_TOP, x2: CHART_WIDTH, y2: CHART_TOP, class: "ads-chart__grid"),
            tag.line(x1: 0, y1: baseline, x2: CHART_WIDTH, y2: baseline, class: "ads-chart__axis"),
            tag.text(top_label, x: 0, y: CHART_TOP - 5, class: "ads-chart__label ads-chart__label--start"),
            *contents, *labels
          ])
        end
      end
  end
end
