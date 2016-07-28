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
          user_address.is_default = true
          if user_address.new_record?
            # Self-registration off
            redirect_to(home_url) && return unless Setting.self_registration?

            # Create on the fly
            user = User.new

            user.firstname, user.lastname = tweet_book.name.split(' ') unless tweet_book.name.nil?
            if user.firstname.blank?
              user.firstname = user_address.address
            end

            if user.lastname.blank?
              user.lastname = user.firstname
            end

            user.random_password
            user.register

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
          office = Office365.new(params[:code], authorize_url)
          token = office.access_token
          jwt = get_email_from_id_token token.params['id_token']

          tweet_book = TweetBook.find_by_provider_and_uid('office365', jwt['email']) || TweetBook.create_with_jwt_hash(jwt)

          user_address = EmailAddress.where(address: tweet_book.email).first_or_initialize
          user_address.is_default = true
          if user_address.new_record?
            # Self-registration off
            redirect_to(home_url) && return unless Setting.self_registration?

            # Create on the fly
            user = User.new
            user.firstname, user.lastname = tweet_book.name.split(' ') unless tweet_book.name.nil?
            user.random_password
            user.register

            if user.firstname.blank?
              user.firstname = user_address.address
            end

            if user.lastname.blank?
              user.lastname = user.firstname
            end

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