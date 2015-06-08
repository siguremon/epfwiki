EPFWikiRails3::Application.routes.draw do

  match 'rss/:site_folder' => 'rss#list', :defaults => {:format => 'atom'} 
  
  resources :comments, :uploads
  
  resources :search do
    collection do
      get :tasks
    end
  end
  
  match 'users/edit', :to => 'users#edit'
  resources :users do
    collection do 
      get :list
      get :account
      get :admin_message
      post :admin_message
      get :send_report
      post :send_report
      get :notification
    end
  end
  #match 'users/send_report/:type', :to => 'users#send_report'
  match 'users/cadmin/:id', :to => 'users#cadmin'
  match 'users/cadmin/:id/:admin', :to => 'users#cadmin'
  match 'users/admin/:id', :to => 'users#admin'

  match 'sites/new', :to => 'sites#new' # TODO shouldn't be necessary?

  match 'sites/:id/edit', :to => 'sites#edit'
  match 'sites/comments/:id', :to => 'sites#comments'
  match 'sites/csv/:id', :to => 'sites#csv'
  match 'sites/update_now/:update_id', :to => 'sites#update_now'
  match 'sites/versions/:id', :to => 'sites#versions'
  match 'sites/obsolete/:id', :to => 'sites#obsolete'
  match 'sites/pages/:id', :to => 'sites#pages'
  match 'sites/uploads/:id', :to => 'sites#uploads'
  match 'sites/feedback/:id', :to => 'sites#feedback'
  match 'sites/update_cancel', :to => 'sites#update_cancel'

  resources :sites do
    collection do
      get :description
      get :list
      get :new_wiki
      post :new_wiki
      post :schedule_update
    end
  end

  resources :login do
    collection do
      get :login
      post :login
      get :logout
      get :lost_password
      post :lost_password
      get :sign_up
      post :sign_up
      get :new_cadmin
      post :new_cadmin
      #get :confirm_account
      post :change_password
      get :change_password
    end
  end

match 'login/confirm_account/:id', :to => 'login#confirm_account' # used for confirmation link
  
  resources :portal do
    collection do
      get :feedback
      post :feedback
      get :home
      get :wikis
      get :users
      get :about
      get :feedback
      get :privacypolicy
      get :termsofuse
      get :search
    end
  end
  
  
  resources :other do
    collection do
      get :about
      get :error
      get :reset
      post :reset
    end
  end

  resources :feedbacks do
    collection do
      get :list
      get :wikis #?
    end
  end

  resources :rss do # TODO nogidg
    get 'list', :on => :collection
  end

  match'archives/:year/:month' , :to => 'portal#archives'

  match 'review/note/:id/:class_name', :to => 'review#note'
  match 'review/note/:id', :to => 'review#note'

  resources :versions do
    post 'diff', :on => :collection
    get 'diff', :on => :collection
  end
  #match 'versions/diff/:id', :to => 'versions#diff' # TODO niet nodig
  match 'versions/text/:id', :to => 'versions#text'
  match 'versions/note/:id/:class_name', :to => 'versions#note'

  #match ':site_folder/:id/:action', :controller => 'pages'#, :as => "page_wikilink"
  #match ':site_folder/:id/:action', :controller => 'pages'
  
  match '', :controller => 'portal', :action => 'home', :title => 'Welcome'
  
  resources :review do
    collection do
      get :toggle_done
      get :assign
    end
  end
  
  match ':site_folder/:id/edit', :to => 'pages#edit'
  match ':site_folder/:id/discussion', :to => 'pages#discussion'
  match ':site_folder/:id/history', :to => 'pages#history'
  match ':site_folder/:id/new', :to => 'pages#new'
  match ':site_folder/:id/search', :to => 'pages#search'
  
  resources :pages do
    collection do
      get :edit
      #post :edit
      #get :discussion
      post :discussion
      post :save
      post :checkin
      put :checkin
      post :rollback
      post :undocheckout
      post :preview
      post :view # TODO Rails 3. Route only used for testing, the app will use the match route. This cannot be combined in Rails 3, it seems
      get :checkout
      post :checkout
    end
  end
  
  resources :updates

  #match 'pages/checkout/:id', :to => 'pages#checkout'
  #match 'pages/view/:id?url=:url', :to => 'pages#view' # see wiki.js: pages/view/id?url=.. TODO dit werkt niet, logisch?
  match 'pages/view/:id', :to => 'pages#view' # see wiki.js: pages/view/id?url=.. # TODO maar dit werkt ook niet!?

  # Last route in routes.rb
  # See http://techoctave.com/c7/posts/36-rails-3-0-rescue-from-routing-error-solution
  match '*a', :to => 'other#show404'
  
  
  #match ':site_folder/:id/:action', :to => 'pages'
  #match ':site_folder/:id/:action', :to => 'pages'
  
  #match ':site_folder'
  
  
  #match 'rss/:site_folder',
  #  :controller => 'rss',
  #  :action => 'list',
  #  :requirements => {:site_folder => /.*/}
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'


# OUD

  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action
  
  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)
  
  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"
  
  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  #map.connect ':controller/service.wsdl', :action => 'wsdl'
  
  # Install the default route as the lowest priority.
  #map.connect 'archives/:year/:month' ,
  #:controller => 'portal' ,
  #:action => 'archives' ,
#  :year => Time.now.year, # disabled
 # :month => Time.now.month, # disabled
  #:requirements => {
#  :year => /\d+/,
#  :month => /\d+/
#  }
  
  # author - RB
  # A route for generating feed for a given practice from a given wiki site.
  # http://myepfwiki/rss/[wiki folder]/practice/[practice_name]  
  # for example "http://epf.eclipse.org/rss/EPF_Practices/practice/iterative_development" returns a feed with all elements of Iterative Development practice found in the EPF_Practices Wiki
#  map.connect "rss/:site_folder/practice/:practice_name",
#    :controller => 'rss',
#    :action => 'practice_feed',
#    :requirements => {:site_folder => /.*/,
#                      :practice_name => /.*/}

  # author - RB
  # A route for generating feed for all elements of a given uma_type found in a given wiki site.
  # http://myepfwiki/rss/[wiki folder]/[uma_type]  
  # for example "http://epf.eclipse.org/rss/EPF_Practices/practice" returns a feed with all practices in the EPF Practices Wiki
 # map.connect "rss/:site_folder/:uma_type",
 #   :controller => 'rss',
 #   :action => 'any_uma_type_feed',
 #   :requirements => {:site_folder => /.*/,
  #                    :uma_type => /.*/}


# TODO implement
#  map.connect 'pages/list/:type',
#    :controller => 'pages',
#    :action => 'list',
#    :requirements => {:type => /\D+/}

 # map.connect 'rss/:site_folder',
 #   :controller => 'rss',
 #   :action => 'list',
 #   :requirements => {:site_folder => /.*/}
 # map.connect ':controller/:action/:id.:format'
 # map.connect ':controller/:action/:id'
  # TODO evaluate this
 # map.connect ':site_folder/:id/:action',
 #   :controller => 'pages'
 # map.connect '', :controller => 'portal', :action => 'home', :title => 'Welcome'

  # See http://rambleon.org/2007/03/07/rails-12-route-changes-are-a-pain-in-the-arse/
  # The following made sense for Apache, but not for LiteSpeed. 
  # BTW, LiteSpeed can be configured to use a custom error page
 # map.connect '*path', :controller => 'other', :action => 'show404', :requirements => { :path => /.*/ }

end
