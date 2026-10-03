# The install's custom CSS (Settings > Appearance), served as a stylesheet so views never carry a
# <style>. Its address holds a digest of the CSS, so browsers keep it until it changes.
class ThemesController < ApplicationController
  allow_unauthenticated_access

  def show
    setting = Setting.current
    return head(:not_found) if setting.custom_css.blank?

    expires_in 1.year, public: true if params[:digest] == setting.custom_css_digest
    render plain: setting.custom_css, content_type: "text/css"
  end
end
