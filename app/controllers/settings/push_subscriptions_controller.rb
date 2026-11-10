# Settings > Your account > Notifications on this device: the browser (or the installed app) you're
# using says it may show your notifications, or stops (the push controller sends what the browser's
# push service gave it). One per browser, kept by its endpoint. Only a person in their own browser
# does this: an agent has no browser to show them in.
class Settings::PushSubscriptionsController < ApplicationController
  allow_staff
  browser_only :create, :destroy, reason: "a browser asks to show its person's notifications, in that browser"

  def create
    subscription = PushSubscription.find_or_initialize_by(endpoint: params.expect(:endpoint))
    keys = params.expect(keys: %i[p256dh auth])
    subscription.update!(user: Current.user, p256dh_key: keys[:p256dh], auth_key: keys[:auth], user_agent: request.user_agent)
    head :created
  end

  def destroy
    Current.user.push_subscriptions.where(endpoint: params[:endpoint]).delete_all
    head :no_content
  end
end
