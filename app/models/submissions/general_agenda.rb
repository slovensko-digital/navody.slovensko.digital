class Submissions::GeneralAgenda
  include ActiveModel::Model

  attr_accessor :recipient_uri
  attr_accessor :subject
  attr_accessor :body
  attr_accessor :attachments
  attr_accessor :token
  attr_accessor :callback_url
  attr_accessor :signed_form_base64
  attr_accessor :require_signed_form

  validates_presence_of :recipient_name, message: 'Vyplňte príjemcu podania', unless: -> { validation_context == :sign }
  validates_presence_of :subject, message: 'Vyplňte predmet podania'
  validates_presence_of :body, message: 'Vyplňte obsah podania'
  # TODO validate token using public key & expirity
  validate :recipient_uri_allowed, if: -> { recipient_uri.present? }

  def save
    return unless valid?
    # TODO submit the form else setup errors
    return true
  end

  def token_payload
    @token_payload, _ = JWT.decode(@token, nil, false) unless @token_payload && @token
    @token_payload
  end

  def recipient_name
    @recipient_name ||= Datahub::Upvs::PublicAuthorityEdesk.where(uri: recipient_uri).pluck(:name).first
  end

  def form_signed?
    !!signed_form
  end

  def signed_form
    return nil unless @signed_form_base64.present?
    @signed_form ||= Submissions::SignedForm.parse(@signed_form_base64)
  end

  def requires_signed_form?
    @require_signed_form
  end

  private

  def recipient_uri_allowed
    unless Datahub::Upvs::PublicAuthorityEdesk.where(uri: recipient_uri).exists?
      errors.add(:recipient_name, "Príjimateľ je neznámy")
    end
  end
end
