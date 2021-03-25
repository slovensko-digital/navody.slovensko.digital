class Submissions::GeneralAgendasController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:new]
  before_action :load_general_agenda, only: [:new, :sign, :create, :submit, :continue]

  def new
  end

  def create
    unless @general_agenda.valid?
      render :new, status: :unprocessable_entity
    end
  end

  def sign
    unless @general_agenda.valid?(:sign)
      render :new, status: :unprocessable_entity
    end
  end

  def submit
    if @general_agenda.save
      if @general_agenda.callback_url.present?
        render action: :continue
      else
        redirect_to action: :finish
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def continue
    redirect_to @general_agenda.callback_url
  end

  def finish
  end

  def login_callback
    session[:eid_token] = params[:token]
    @token = params[:token]

    render layout: false # TODO show something nice
  end

  def switch_account_callback
    session.delete(:eid_token)
    @token = nil
    render action: :login_callback, layout: false # TODO run logout/login flow
  end

  private

  def load_general_agenda
    @general_agenda = Submissions::GeneralAgenda.new(general_agenda_params)
    @general_agenda.token = session[:eid_token] if @general_agenda.token.blank? && session[:eid_token]
    if @general_agenda.signed_form # TODO support for other forms
      @general_agenda.subject = @general_agenda.signed_form.form.subject
      @general_agenda.body = @general_agenda.signed_form.form.body
    end
  end

  def general_agenda_params
    params.require(:submissions_general_agenda).permit(
      :recipient_uri,
      :subject, :body,
      :attachments,
      :token,
      :signed_form_base64,
      :require_signed_form,
    ) if params.key?(:submissions_general_agenda)
  end
end
