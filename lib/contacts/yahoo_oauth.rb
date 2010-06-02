module Contacts
  class YahooOAuth < OAuthConsumer
    CONSUMER_OPTIONS = Util.frozen_hash(
      :site => "https://api.login.yahoo.com",
      :request_token_path => "/oauth/v2/get_request_token",
      :access_token_path => "/oauth/v2/get_token",
      :authorize_path => "/oauth/v2/request_auth"
    )

    REQUEST_TOKEN_PARAMS = Util.frozen_hash

    def initialize(options={})
      super(CONSUMER_OPTIONS, REQUEST_TOKEN_PARAMS)
    end

    def contacts(options={})
      params = {:limit => 200}.update(options)
      yahoo_params = translate_contacts_options(params).merge('format' => 'json')
      guid = @access_token.params['xoauth_yahoo_guid']
      uri = URI.parse("http://social.yahooapis.com/v1/user/#{guid}/contacts")
      uri.query = params_to_query(yahoo_params)
      response = @access_token.get(uri.to_s)
      parse_contacts(response.body)
    end

    def serialize
      params = {}
      params['access_token'] = serialize_oauth_token(@access_token) if @access_token
      params['request_token'] = serialize_oauth_token(@request_token) if @request_token
      params_to_query(params)
    end

    private

    def translate_contacts_options(options)
      params = {}
      value = options[:limit] and
        params['count'] = value
      value = options[:offset] and
        params['start'] = value
      params['sort'] = (value = options[:descending]) ? 'desc' : 'asc'
      params['sort-fields'] = 'email'
      # :updated_after not supported. Yahoo! appears to support
      # filtering by updated, but does not support a date comparison
      # operation. Lame. TODO: filter unwanted records out of the
      # response ourselves.
      params
    end

    def parse_contacts(text)
      result = JSON.parse(text)
      result['contacts']['contact'].map do |contact_object|
        name, emails = nil, []
        contact_object['fields'].each do |field_object|
          case field_object['type']
          when 'nickname'
            name = field_object['value']
          when 'name'
            name ||= field_object['value'].values_at('givenName', 'familyName').compact.join(' ')
          when 'email'
            emails << field_object['value']
          end
        end
        next if emails.empty?
        contact = Contact.new(nil, name)
        contact.emails.concat(emails)
        contact
      end.compact
    end
  end
end