class Office365

  attr_accessor :access_token, :client, :raw_info, :jwt_info

  OFFICE365_JWT_USER_IDENTIFER = 'oid'.freeze
  OFFICE365_JWT_ORGANIZATION_IDENTIFER = 'tid'.freeze
  OFFICE365_JWT_USER_PRINCIPAL_NAME = 'upn'.freeze

  def initialize(auth_code, authorize_url)
    @client = OAuth2::Client.new($tweetbook_settings['office365']['key'],
                                $tweetbook_settings['office365']['secret'],
                                :site => 'https://outlook.office.com/',
                                :authorize_url => 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
                                :token_url => 'https://login.microsoftonline.com/common/oauth2/v2.0/token')


  @access_token =  client.auth_code.get_token(auth_code,
                                              :redirect_uri => authorize_url,
                                              :scope => $office_scope.join(' '))
  end


  def use_faraday
    conn = Faraday.new(:url => 'https://outlook.office.com') do |faraday|
      # Outputs to the console
      faraday.response :logger
      # Uses the default Net::HTTP adapter
      faraday.adapter  Faraday.default_adapter
    end

    response = conn.get do |request|
      # Get messages from the inbox
      # Sort by ReceivedDateTime in descending orderby
      # Get the first 20 results
      request.url '/api/v2.0/me'
      request.headers['Authorization'] = "Bearer #{access_token.token}"
      request.headers['Accept'] = 'application/json'
    end
    response
  end

  def raw_info
    @raw_info ||= access_token.get('api/v2.0/me').parsed
  end

  def decoded_jwt_token
    JWT.decode(access_token.token, nil, false)
  rescue JWT::DecodeError
    []
  end

  def jwt_info
    @jwt_info ||= decoded_jwt_token.first || {}
  end

  def parsed_email
    return raw_info['EmailAddress'] if jwt_info.empty?

    jwt_info[OFFICE365_JWT_USER_PRINCIPAL_NAME]
  end

  def parsed_uid
    return raw_info['Id'] if jwt_info.empty?

    [
        jwt_info[OFFICE365_JWT_USER_IDENTIFER],
        jwt_info[OFFICE365_JWT_ORGANIZATION_IDENTIFER]
    ].join('@')
  end
end