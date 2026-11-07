# Undoes the "General" project the v1 import used to make per client for work v1 kept with no
# project (Import::V1 now puts that work straight on the client). For each one: its work, notes
# and documents (and any time logged on it, with Time tracking installed) move onto its client,
# then the emptied project is closed and erased, which leaves a piece of work.erased event on the
# client. Only projects the importer made match: titled General, with the importer's description.
# A dry run unless told to apply.
#
#   bin/rails import:unfold_general            # says what it would do
#   bin/rails "import:unfold_general[apply]"   # does it
module Import
  class UnfoldGeneral
    DESCRIPTION = "<p>Work that had no project in Runwell v1.</p>".freeze

    def initialize(apply: false, out: $stdout)
      @apply = apply
      @out = out
    end

    def self.matches
      Work.where(title: "General", label: "project").includes(:client).select { it.description.to_s.strip == DESCRIPTION }
    end

    def run
      found = self.class.matches
      return @out.puts("No General projects from the v1 import here.") if found.empty?

      found.each do |work|
        counts = { work: work.tasks.count, notes: work.notes.count, documents: work.documents.count }
        @out.puts "#{work.ref} General (#{work.client.name}): #{counts.map { |kind, count| "#{count} #{kind}" }.join(", ")} #{@apply ? "moved onto the client; project erased" : "would move onto the client"}"
        unfold(work) if @apply
      end
      @out.puts(@apply ? "Done: #{found.size} unfolded." : "Nothing changed. Run bin/rails \"import:unfold_general[apply]\" to do it.")
    end

    private
      def unfold(work)
        client = work.client
        Current.set(source: "import") do
          Work.transaction do
            work.tasks.to_a.each { it.update!(work: nil, scope_item: nil) }
            work.notes.to_a.each { it.update!(subject: client) }
            work.documents.to_a.each { it.update!(documentable: client) }
            TimeTracking::Entry.where(trackable: work).update_all(trackable_type: "Client", trackable_id: client.id) if defined?(TimeTracking::Entry)
            work.reload
            work.close!(reason: "Its work moved onto #{client.name}", actor: nil) unless work.closed?
            work.erase!(actor: nil)
          end
        end
      end
  end
end
