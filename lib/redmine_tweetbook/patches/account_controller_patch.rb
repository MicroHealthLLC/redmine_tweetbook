module RedmineTweetbook
  module Patches
    module AccountControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do

        end
      end

      module InstanceMethods        
        def tweetbook_authenticate
          auth_hash = request.env['omniauth.auth']
          tweet_book = TweetBook.find_by_provider_and_uid(auth_hash['provider'], auth_hash['uid']) || TweetBook.create_with_auth_hash(auth_hash)

          user_address = EmailAddress.where(address: tweet_book.email).first_or_initialize
          if user_address.new_record?
            # Self-registration off
            redirect_to(home_url) && return unless Setting.self_registration?

            # Create on the fly
            user = User.new

            user.firstname, user.lastname = tweet_book.name.split(' ') unless tweet_book.name.nil?
            user.random_password
            user.register


            user_address.is_default = true
            user.email_address = user_address
            user.login = user_address.address if user.login.blank?


            case Setting.self_registration
              when '1'
                register_by_email_activation(user) do
                  onthefly_creation_failed(user)
                end
              when '3'
                register_automatically(user) do
                  onthefly_creation_failed(user)
                end
              else
                register_manually_by_administrator(user) do
                  onthefly_creation_failed(user)
                end
            end
            tweet_book.update_attribute :user_id, user.id
          else
            # Existing record
            if user_address.user.active?
              successful_authentication(user_address.user)
            else
              handle_inactive_user user_address.user
            end
          end	
        rescue AuthSourceException => e
          logger.error "An error occured when authenticating #{e.message}"
          render_error :message => e.message
        end

        def office_authenticate
          token = get_token_from_code params[:code]
          azure_token = token.token
          jwt = get_email_from_id_token token.token
          tweet_book = TweetBook.find_by_provider_and_uid('office365', jwt['tid']) || TweetBook.create_with_jwt_hash(jwt)

          user_address = EmailAddress.where(address: tweet_book.email).first_or_initialize
          if user_address.new_record?
            # Self-registration off
            redirect_to(home_url) && return unless Setting.self_registration?

            # Create on the fly
            user = User.new
            user.firstname, user.lastname = tweet_book.name.split(' ') unless tweet_book.name.nil?
            user.random_password
            user.register

            user_address.is_default = true
            user.email_address = user_address
            user.login = user_address.address if user.login.blank?

            case Setting.self_registration
              when '1'
                register_by_email_activation(user) do
                  onthefly_creation_failed(user)
                end
              when '3'
                register_automatically(user) do
                  onthefly_creation_failed(user)
                end
              else
                register_manually_by_administrator(user) do
                  onthefly_creation_failed(user)
                end
            end
            tweet_book.update_attribute :user_id, user.id
          else
            # Existing record
            if user_address.user.active?
              successful_authentication(user_address.user)
            else
              handle_inactive_user(user_address.user)
            end
          end
        end

        private

        def get_token_from_code(auth_code)
          client = OAuth2::Client.new($tweetbook_settings['office365']['key'],
                                      $tweetbook_settings['office365']['secret'],
                                      :site => 'https://login.microsoftonline.com',
                                      :authorize_url => '/common/oauth2/v2.0/authorize',
                                      :token_url => '/common/oauth2/v2.0/token')

          client.auth_code.get_token(auth_code,
                                     :redirect_uri => 'https://plan.microhealthllc.com/authorize',
                                     :scope => $office_scope.join(' '))
        end

        def get_email_from_id_token(id_token)

          # JWT is in three parts, separated by a '.'
          token_parts = id_token.split('.')
          # Token content is in the second part
          encoded_token = token_parts[1]

          # It's base64, but may not be padded
          # Fix padding so Base64 module can decode
          leftovers = token_parts[1].length.modulo(4)
          if leftovers == 2
            encoded_token += '=='
          elsif leftovers == 3
            encoded_token += '='
          end

          # Base64 decode (urlsafe version)
          decoded_token = Base64.urlsafe_decode64(encoded_token)

          # Load into a JSON object
          jwt = JSON.parse(decoded_token)

          jwt
        end

      end
    end # end Account Controller patch
  end
end

unless AccountController.included_modules.include?(RedmineTweetbook::Patches::AccountControllerPatch)
  AccountController.send(:include, RedmineTweetbook::Patches::AccountControllerPatch)
end