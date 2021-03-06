require 'redmine'

Redmine::Plugin.register :redmine_tweetbook do
  name 'TweetBook'
  author 'sandeepleo11'
  description 'Facebook, Twitter, Github authentication plugin for Redmine.'
  version '1.0'
  url 'http://github.com/sandeepleo11/redmine_tweetbook'
  author_url 'mailto:me@sandeep.me'

  $tweetbook_settings = YAML::load(File.open("#{File.dirname(__FILE__)}/config/settings.yml"))
  $office_scope = [ 'openid',
                    'https://outlook.office.com/mail.read',
                    'profile', 'email'
  ]
end

Rails.application.config.middleware.use OmniAuth::Builder do
  # provider :developer unless Rails.env.production?  
  provider :twitter, $tweetbook_settings['twitter']['key'], $tweetbook_settings['twitter']['secret']
  provider :facebook, $tweetbook_settings['facebook']['key'], $tweetbook_settings['facebook']['secret']
  provider :github, $tweetbook_settings['github']['key'], $tweetbook_settings['github']['secret']
  # provider :microsoft_office365, $tweetbook_settings['office365']['key'], $tweetbook_settings['office365']['secret']
end




require 'redmine_tweetbook'