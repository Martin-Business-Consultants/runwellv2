json.summary "#{@work_types.count { !it.archived? }} #{"work type".pluralize(@work_types.count { !it.archived? })} in use#{", #{@work_types.count(&:archived?)} switched off" if @work_types.any?(&:archived?)}"
json.work_types @work_types do |type|
  json.extract! type, :key, :name_one, :name_other, :prefix, :description, :system, :shape, :cadence, :check_in, :position
  json.starting_sections type.starting_sections.to_a
  json.runs type.runs
  json.archived type.archived?
  json.works type.works_count
  json.deletable type.deletable?
  json.mergeable type.mergeable?
end
