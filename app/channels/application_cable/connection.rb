module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        # Someone on staff, or a client's person signed in to the portal (its pages refresh live
        # too; a stream's name is signed into the page, so each sees only what theirs names).
        staff = Session.find_by(id: cookies.signed[:session_id])&.user if cookies.signed[:session_id]
        self.current_user = staff || (Session.find_by(id: cookies.signed[:portal_session_id])&.contact&.then { it if it.portal? } if cookies.signed[:portal_session_id])
      end
  end
end
