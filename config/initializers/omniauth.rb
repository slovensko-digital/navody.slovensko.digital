require 'omniauth/strategies/magic_link'
OmniAuth.config.logger = Rails.logger
OmniAuth.config.failure_raise_out_environments = []

Rails.application.config.middleware.use OmniAuth::Builder do
  google_client_id = Rails.application.config_for(:auth).dig(:google, :client_id)
  google_client_secret = Rails.application.config_for(:auth).dig(:google, :client_secret)

  provider :google_oauth2, google_client_id, google_client_secret
  provider :magic_link, {
    on_send_link: -> (email, token) {
      UserMailer.with(email: email, token: token).magic_link.deliver_later
    }
  }
end

