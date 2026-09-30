module AccountManagement
  # A meeting's agenda before it, or its recap after, to one of the client's contacts.
  class MeetingMailer < ::ApplicationMailer
    helper ::ApplicationHelper, ::AgentHelper

    def paper
      @meeting = params[:meeting]
      @contact = params[:contact]
      @paper = params[:paper]
      @meeting.client.in_time_zone do
        subject = @paper == "agenda" ? "Agenda: #{@meeting.title}, #{@meeting.when_label}" : "Recap: #{@meeting.title}"
        mail to: @contact.email, subject: subject
      end
    end
  end
end
