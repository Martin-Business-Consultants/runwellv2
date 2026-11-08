# Template mode (RecordLayout): how a kind of record's fields are arranged on its pages, for the
# whole install. Owners arrange them on the pages themselves (record-layout controller), which
# send each column's field keys in order; agents can read and set the same.
class Settings::LayoutsController < ApplicationController
  allow_staff
  require_permission :manage_settings, only: %i[update destroy]
  agent_tool :show_layout, on: :show, title: "Show how a kind of record's fields are arranged",
    description: "kind: client, work, task, contact, user or portal_work. Each field's key and name, in order, in main (the working column), aside (the sidebar) or hidden, and which can't be hidden. It changes only where fields show on the record's own pages."
  agent_tool :arrange_layout, on: :update, title: "Arrange a kind of record's fields",
    description: "kind: client, work, task, contact, user or portal_work. Field keys (from show_layout) in order for main, aside and hidden; a key left out keeps its column, and required ones can't be hidden. text renames card headings by slot (show_layout lists them: main.title, main.hint, aside.title; on portal_work <card>.title and <card>.hint); a blank one goes back to its default; leave text out to keep them. For everyone on this install; it changes only where fields show on the record's pages, not what's stored or required.",
    params: { layout: { main: "string[]", aside: "string[]", hidden: "string[]", text: {} } }
  agent_tool :reset_layout, on: :destroy, title: "Put a kind of record's fields back as they came"

  before_action :set_kind

  def show
    @layout = Setting.current.layout(@kind)
  end

  def update
    layout = params.fetch(:layout, {}).permit(main: [], aside: [], hidden: [], text: {})
    Setting.current.arrange_layout!(@kind, main: layout[:main], aside: layout[:aside], hidden: layout[:hidden], text: layout[:text]&.to_h)
    redirect_back fallback_location: root_path, notice: "#{noun} fields are arranged for everyone."
  end

  def destroy
    Setting.current.reset_layout!(@kind)
    redirect_back fallback_location: root_path, notice: "#{noun} fields are back as they came."
  end

  private
    def set_kind
      @kind = params[:kind].presence_in(RecordLayout::KINDS) or raise ActiveRecord::RecordNotFound
    end

    def noun = { "user" => "People’s", "contact" => "Contacts’", "portal_work" => "The portal page’s" }.fetch(@kind) { "#{helpers.term(@kind.to_sym)}’s" }
end
