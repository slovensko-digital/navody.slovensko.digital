class Apps::ParliamentVoteApp::ApplicationFormsController < ApplicationController
  before_action :set_metadata, :check_inactive_parliament_application

  def show
    render_step('start')
  end

  def create
    merge_params
    render_self
  end

  def authorized_person; process_or_render('authorized_person'); end
  def authorized_person_send; process_or_render('authorized_person_send'); end
  def delivery; process_or_render('delivery'); end
  def delivery_address; process_or_render('delivery_address'); end
  def identity; process_or_render('identity'); end
  def permanent_resident; process_or_render('permanent_resident'); end
  def place; process_or_render('place'); end
  def to_send; process_or_render('send'); end
  def sk_citizen; process_or_render('sk_citizen'); end
  def world_abroad_permanent_resident; process_or_render('world_abroad_permanent_resident'); end
  def world_abroad_permanent_resident_end; process_or_render('world_abroad_permanent_resident_end'); end
  def world_sk_permanent_resident; process_or_render('world_sk_permanent_resident'); end
  def world_sk_permanent_resident_end; process_or_render('world_sk_permanent_resident_end'); end

  def redirect_to_step(step)
    set_form_state form_state.merge(step: step)
    redirect_to self.public_send(:"#{step}_apps_parliament_vote_app_application_forms_url")
  end

  def redirect_to_begining
    redirect_to action: :show
  end

  def render_form
    render form_params[:step]
  end

  private def process_or_render(step)
    if request.post?
      return create
    elsif form_state.empty?
      return redirect_to_begining
    end
    render_step(step)
  end

  private def merge_params
    set_form_state form_state.merge(form_params)
  end

  private def form_state
    ActiveSupport::HashWithIndifferentAccess.new(session.fetch(Apps::ParliamentVoteApp::ApplicationForm::STATE_KEY, {}))
  end

  private def set_form_state(value)
    session[Apps::ParliamentVoteApp::ApplicationForm::STATE_KEY] = value.to_h
  end


  private def render_self
    @application_form = Apps::ParliamentVoteApp::ApplicationForm.new(form_state)
    @application_form.run(self)
  end

  private def render_step(step)
    set_form_state form_state.merge(step: step)
    @application_form = Apps::ParliamentVoteApp::ApplicationForm.new(form_state)
    if @application_form.allowed_step?(step)
      render step
    else
      redirect_to_begining
    end
  end

  private def form_params
    params.require(:apps_parliament_vote_app_application_form).permit(
      :step,
      :place,
      :sk_citizen,
      :delivery,
      :full_name, :pin, :nationality, :maiden_name,
      :authorized_person_full_name, :authorized_person_pin,
      :street, :pobox, :municipality,
      :same_delivery_address,
      :delivery_street, :delivery_pobox, :delivery_municipality, :delivery_country,
      :municipality_email,
      :municipality_email_verified,
      :permanent_resident,
      :back
    )
  end

  private def set_metadata
    @metadata.og.title = 'Žiadosť o hlasovací preukaz alebo voľbu poštou'
    @metadata.og.image = 'facebook_share_2020.png'
    @metadata.og.description = 'Či budete počas volieb v zahraničí alebo mimo trvalého pobytu, voliť sa dá. Stačí požiadať.'
  end

  private def check_inactive_parliament_application
    return if Apps::ParliamentVoteApp::ApplicationForm.active?
    return redirect_to apps_parliament_vote_app_application_forms_path if action_name != "show"
    render 'inactive'
  end
end
