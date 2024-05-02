# frozen_string_literal: true

# Helps with JWT-based authentication in specs
def jwt
  JWT.encode({ sub: 'dsa' }, Settings.hmac_secret, 'HS256')
end
