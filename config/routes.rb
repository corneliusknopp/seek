SEEK::Application.routes.draw do

  ### GENERAL PAGES ###

  root :to => "homes#index"

  resource :admin do
    member do
      get :show
      get :tags
      get :features_enabled
      get :rebrand
      get :home_settings
      get :pagination
      get :biosamples_renaming
      get :others
      get :get_stats
      get :registration_form
      get :restart_server
      get :update_home_settings
      post :get_stats
      post :update_admins
      post :update_rebrand
      post :test_email_configuration
      post :update_others
      post :update_features_enabled
      post :update_pagination
      post :delete_tag
      post :edit_tag
    end
  end

  resource :home do
    member do
      get :index
      get :feedback
      post :send_feedback
    end
  end

  match 'index.html' => 'homes#index', :as => :match
  match 'index' => 'homes#index', :as => :match

  resource :favourites do
    collection do
      post :add
    end
    member do
      delete :delete
    end
  end

  resources :help_documents do
    resources :help_attachments, :only => [:create, :destroy] do
      member do
        get :download
      end
    end
    resources :help_images, :only => [:create, :destroy]
  end

  resources :forum_attachments, :only => [:create, :destroy] do
    member do
      get :download
    end
  end

  resources :avatars
  resources :attachments
  resources :subscriptions
  resources :measured_items
  resources :saved_searches
  resources :uuids
  resources :compounds

  ### USERS AND SESSIONS ###

  resources :users do
    collection do
      get :activation_required
      get :forgot_password
      get :reset_password
      post :forgot_password
      post :hide_guide_box
      post :impersonate
    end
    member do
      put :set_openid
    end
  end

  resource :session do
    collection do
      get :index
      get :show
      get :auto_openid
    end
    member do
      get :show
    end

  end

  ### YELLOW PAGES ###

  resources :people do
    collection do
      get :select
      get :get_work_group
    end
    member do
      get :check_related_items
      get :check_gatekeeper_required
      get :admin
      get :published
      get :batch_publishing_preview
      get :publish_related_items
      put :administer_update
      post :publish
    end
    resources :avatars do
      member do
        post :select
      end
    end
  end

  resources :projects do
    collection do
      get :request_institutions
      get :view_items_in_tab
    end
    member do
      get :asset_report
      get :admin
    end
    resources :avatars do
      member do
        post :select
      end

    end
    resources :folders do
      collection do
        post :nuke
      end
      member do
        post :remove_asset
        post :display_contents
        post :move_asset_to
        post :create_folder
        post :set_project_folder_title
        post :set_project_folder_description
      end
    end
  end

  resources :institutions do
    collection do
      get :request_all
    end
    resources :avatars do
      member do
        post :select
      end
    end
  end

  ### ISA ###

  resources :investigations do
    member do
      get :approve_or_reject_publish
      post :gatekeeper_decide
    end
  end

  resources :studies do
    member do
      get :approve_or_reject_publish
      post :gatekeeper_decide
    end
    collection do
      post :investigation_selected_ajax
    end
  end

  resources :assays do
    collection do
      get :preview
    end
    member do
      get :approve_or_reject_publish
      post :gatekeeper_decide
      post :update_annotations_ajax
    end
  end

  resources :assay_types do
    collection do
      get :manage
    end
  end

  resources :technology_types do
    collection do
      get :manage
    end
  end

  ### ASSETS ###

  resources :data_files do
    collection do
      get :preview
      get :view_items_in_tab
      post :test_asset_url
      post :upload_for_tool
      post :upload_from_email
    end
    member do
      get :check_related_items
      get :matching_models
      get :data
      get :check_gatekeeper_required
      get :plot
      get :explore
      get :download
      get :published
      get :approve_or_reject_publish
      get :publish_related_items
      post :publish
      post :request_resource
      post :convert_to_presentation
      post :update_annotations_ajax
      post :gatekeeper_decide
      post :new_version
    end
    resources :studied_factors do
      collection do
        post :create_from_existing
      end
    end
    resources :content_blobs do
      member do
        get :view_pdf_content
        get :get_pdf
        get :download
      end
    end
  end

  resources :presentations do
    collection do
      get :preview
      get :view_items_in_tab
      post :test_asset_url
    end
    member do
      get :check_related_items
      get :check_gatekeeper_required
      get :download
      get :published
      get :approve_or_reject_publish
      get :publish_related_items
      post :publish
      post :request_resource
      post :update_annotations_ajax
      post :gatekeeper_decide
      post :new_version
    end
    resources :content_blobs do
      member do
        get :view_pdf_content
        get :get_pdf
        get :download
      end
    end
  end

  resources :models do
    collection do
      get :build
      get :preview
      get :view_items_in_tab
      post :update_model_metadata
      post :create_model_metadata
      post :test_asset_url
    end
    member do
      get :builder
      get :check_related_items
      get :visualise
      get :check_gatekeeper_required
      get :download
      get :matching_data
      get :published
      get :approve_or_reject_publish
      get :publish_related_items
      post :submit_to_jws
      post :gatekeeper_decide
      post :new_version
      post :submit_to_sycamore
      post :export_as_xgmml
      post :update_annotations_ajax
      post :simulate
      post :publish
      post :execute
      post :request_resource
    end
    resources :model_images do
      collection do
        post :new
      end
      member do
        post :select
      end
    end
    resources :content_blobs do
      member do
        get :view_pdf_content
        get :get_pdf
        get :download
      end
    end
  end

  resources :sops do
    collection do
      get :preview
      get :view_items_in_tab
      post :test_asset_url
    end
    member do
      get :check_related_items
      get :check_gatekeeper_required
      get :download
      get :published
      get :approve_or_reject_publish
      get :publish_related_items
      post :publish
      post :request_resource
      post :update_annotations_ajax
      post :gatekeeper_decide
      post :new_version
    end
    resources :experimental_conditions do
      collection do
        post :create_from_existing
      end
    end
    resources :content_blobs do
      member do
        get :view_pdf_content
        get :get_pdf
        get :download
      end
    end
  end

  resources :publications do
    collection do
      get :preview
      post :fetch_preview
    end
    member do
      post :update_annotations_ajax
      post :disassociate_authors
    end
  end

  resources :events do
    collection do
      get :preview
    end
  end

  resource :policies do
    member do
      get :preview_permissions
    end
  end

  resources :spreadsheet_annotations, :only => [:create, :destroy, :update]

  ### BIOSAMPLES AND ORGANISMS ###

  resources :specimens
  resources :samples

  resources :strains do
    member do
      post :update_annotations_ajax
    end
    collection do
      get :existing_strains_for_assay_organism
    end

  end

  resources :biosamples do
    collection do
      get :existing_strains
      get :existing_specimens
      get :strains_of_selected_organism
      get :existing_samples
      get :strain_form
      put :update_strain
      post :create_specimen_sample
      post :create_strain
      post :create_strain_popup
      post :edit_strain_popup
    end
  end

  resources :organisms do
    member do
      get :visualise
    end
    collection do
      post :search_ajax
    end
  end


  ### MISC MATCHES ###

  match '/search/' => 'search#index', :as => :search
  match '/search/save' => 'search#save', :as => :save_search
  match '/search/delete' => 'search#delete', :as => :delete_search
  match 'svg/:id.:format' => 'svg#show', :as => :svg
  match '/tags' => 'tags#index', :as => :all_tags
  match '/tags/:id' => 'tags#show', :as => :show_tag
  match '/tags' => 'tags#index', :as => :all_anns
  match '/tags/:id' => 'tags#show', :as => :show_ann
  match '/jerm/' => 'jerm#index', :as => :jerm
  match '/countries/:country_name' => 'countries#show', :as => :country

  match '/data_fuse/' => 'data_fuse#show', :as => :data_fuse
  match '/favourite_groups/new' => 'favourite_groups#new', :as => :new_favourite_group, :via => :post
  match '/favourite_groups/create' => 'favourite_groups#create', :as => :create_favourite_group, :via => :post
  match '/favourite_groups/edit' => 'favourite_groups#edit', :as => :edit_favourite_group, :via => :post
  match '/favourite_groups/update' => 'favourite_groups#update', :as => :update_favourite_group, :via => :post
  match '/favourite_groups/:id' => 'favourite_groups#destroy', :as => :delete_favourite_group, :via => :delete
  match 'studies/new_investigation_redbox' => 'studies#new_investigation_redbox', :as => :new_investigation_redbox, :via => :post
  match 'experiments/create_investigation' => 'studies#create_investigation', :as => :create_investigation, :via => :post
  match '/work_groups/review/:type/:id/:access_type' => 'work_groups#review_popup', :as => :review_work_group, :via => :post
  match ':controller/new_object_based_on_existing_one/:id' => "#new_object_based_on_existing_one", :as => :new_object_based_on_existing_one, :via => :post
  match '/tool_list_autocomplete' => 'people#auto_complete_for_tools_name', :as => :tool_list_autocomplete
  match '/expertise_list_autocomplete' => 'people#auto_complete_for_expertise_name', :as => :expertise_list_autocomplete
  match '/organism_list_autocomplete' => 'projects#auto_complete_for_organism_name', :as => :organism_list_autocomplete


  match '/signup' => 'users#new', :as => :signup

  match '/logout' => 'sessions#destroy', :as => :logout
  match '/activate/:activation_code' => 'users#activate', :activation_code => nil, :as => :activate
  match '/forgot_password' => 'users#forgot_password', :as => :forgot_password
  match '/policies/request_settings' => 'policies#send_policy_data', :as => :request_policy_settings

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
