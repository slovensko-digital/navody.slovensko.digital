class JourneysController < ApplicationController
  before_action :redirect_inactive_eu_application
  before_action :redirect_inactive_parliament_application

  def show
    @journey = Journey.displayable.find_by!(slug: params[:id])
    @next_step = @journey.steps.order(:position).first

    load_newest_user_journey(current_user, @journey)

    @metadata.og.image = "journeys/#{@journey.image_name.presence || "placeholder.png" }"
  end

  private def redirect_inactive_eu_application
    return if Apps::EpVoteApp::ApplicationForm.active?
    redirect_to apps_ep_vote_app_application_forms_path if params[:id] == "volby-do-eu-parlamentu"
  end

  private def redirect_inactive_parliament_application
    return if Apps::ParliamentVoteApp::ApplicationForm.active?
    redirect_to apps_ep_vote_app_application_forms_path if params[:id] == "parlamentne-volby"
  end
end
