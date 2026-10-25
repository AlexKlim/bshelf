Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :body, :text, :title, :author, :url, :arguments, :query, :note, :code_verifier, /\Aq\z/
]
