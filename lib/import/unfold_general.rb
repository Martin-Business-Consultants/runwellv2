# Undoes the "General" project the v1 import used to make per client for work v1 kept with no
# project (Import::V1 now puts that work straight on the client). For each one: its work, notes
# and documents (and any time logged on it, with Time tracking installed) move onto its client,
# then the emptied project is closed and erased, which leaves an engagement.erased event on the
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
      Engagement.where(title: "General", label: "project").includes(:client).select { it.description.to_s.strip == DESCRIPTION }
    end

    def run
      found = self.class.matches
      return @out.puts("No General projects from the v1 import here.") if found.empty?

      found.each do |engagement|
        counts = { work: engagement.todos.count, notes: engagement.notes.count, documents: engagement.documents.count }
        @out.puts "#{engagement.ref} General (#{engagement.client.name}): #{counts.map { |kind, count| "#{count} #{kind}" }.join(", ")} #{@apply ? "moved onto the client; project erased" : "would move onto the client"}"
        unfold(engagement) if @apply
      end
      @out.puts(@apply ? "Done: #{found.size} unfolded." : "Nothing changed. Run bin/rails \"import:unfold_general[apply]\" to do it.")
    end

    private
      def unfold(engagement)
        client = engagement.client
        Current.set(source: "import") do
          Engagement.transaction do
            engagement.todos.to_a.each { it.update!(engagement: nil, scope_item: nil) }
            engagement.notes.to_a.each { it.update!(subject: client) }
            engagement.documents.to_a.each { it.update!(documentable: client) }
            TimeTracking::Entry.where(trackable: engagement).update_all(trackable_type: "Client", trackable_id: client.id) if defined?(TimeTracking::Entry)
            engagement.reload
            engagement.close!(reason: "Its work moved onto #{client.name}", actor: nil) unless engagement.closed?
            engagement.erase!(actor: nil)
          end
        end
      end
  end
end
