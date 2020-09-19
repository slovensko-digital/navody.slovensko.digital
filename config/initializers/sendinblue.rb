SibApiV3Sdk.configure do |config|
  # Configure API key authorization: api-key
  config.api_key['api-key'] = Rails.application.config_for(:auth).dig(:sendinblue, :api_key)
end
