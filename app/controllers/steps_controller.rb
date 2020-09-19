class StepsController < ApplicationController
  before_action :redirect_inactive_eu_application, only: :show
  before_action :redirect_inactive_parliament_application, only: :show

  def show
    @journey = Journey.published.find_by!(slug: params[:journey_id])
    @steps = @journey.steps
    @current_step = @steps.find_by!(slug: params[:id])
    @user_step_from_step_map = {}

    @metadata.og.image = "journeys/#{@journey.image_name.presence || "placeholder.png" }"

    load_newest_user_journey(current_user, @journey)
  end

  def update
    @journey = Journey.published.find_by!(slug: params[:journey_id])
    @user_journey = UserJourney.order(id: :desc).find_by(user: current_user, journey: @journey) || current_user.user_journeys.create!(journey: @journey)

    @current_step = @journey.steps.find_by(slug: params[:id])
    @user_step = @user_journey.user_steps.find_or_initialize_by(step: @current_step)
    @user_step.update(status: params['status'])

    respond_to do |format|
      format.html do
        redirect_to [@journey, @current_step]
      end
      format.js do
        @steps = @user_journey.journey.steps
        @user_step_by_steps = @user_journey.user_steps.index_by { |user_step| user_step.step }
        @user_task_by_tasks = @user_journey.user_tasks.index_by { |user_task| user_task.task }
        render 'tasks/complete_or_undo'
      end
    end
  end

  def start
    journey = Journey.published.find_by!(slug: params[:journey_id])
    step = journey.steps.find_by!(slug: params[:id])

    redirect_to step.app_url
  end

  private def redirect_inactive_eu_application
    return if Apps::EpVoteApp::ApplicationForm.active?
    redirect_to apps_ep_vote_app_application_forms_path if params[:journey_id] == "volby-do-eu-parlamentu"
  end

  private def redirect_inactive_parliament_application
    return if Apps::ParliamentVoteApp::ApplicationForm.active?
    redirect_to apps_ep_vote_app_application_forms_path if params[:journey_id] == "parlamentne-volby"
  end
end
