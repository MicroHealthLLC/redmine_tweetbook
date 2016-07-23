RedmineApp::Application.routes.draw do	
  match '/auth/:provider/callback', :to => 'account#tweetbook_authenticate', :via => [:get, :post], :as => 'tweetbook_authenticate'
  # get 'authorize', :to => 'account#tweetbook_authenticate', :via => [:get, :post]
  get 'authorize' => 'account#office_authenticate'
end