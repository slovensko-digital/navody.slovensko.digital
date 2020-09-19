Rails.application.routes.draw do
  get :health, to: 'health#index'

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  namespace :admin do
    root to: redirect('admin/pages')

    resources :documents do
      put :feature, on: :member
      put :hide, on: :member
      post :reposition, on: :collection
    end
    resources :apps, except: [:show]
    resources :pages, except: [:show]
    resources :journeys, except: [:show] do
      resources :steps, except: [:show] do
        resources :tasks, except: [:show]
        member do
          post :reposition
        end
      end
      member do
        post :reposition
      end
    end
    resources :user_journeys
  end

  root to: 'pages#index'

  resource :search, only: [:show]

  resources :journeys, path: 'zivotne-situacie', only: [:show] do
    resources :steps, path: 'krok' do
      get :start, on: :member, path: 'spustit'
      resources :tasks do
        member do
          post :complete
          post :undo
        end
      end
    end
  end

  resources :quick_tips, path: 'caste-otazky', only: :show

  namespace :apps, path: 'aplikacie' do
    namespace :ep_vote_app, path: 'volby-do-europskeho-parlamentu' do
      resource :application_forms, path: '' do
        member do
          get :end, path: 'hlasovacim-preukazom'
          get :world, path: 'hlasovanie-v-zahranici'
          get :eu, path: 'hlasovanie-v-inom-clenskom-state'
          get :home, path: 'hlasovanie-v-mieste-trvaleho-bydliska'
          get :person, path: 'hlasovaci-preukaz-osobne'
          get :non_sk_nationality, path: 'hlasovanie-obcanov-eu-na-slovensku'
        end
      end
    end

    if ENV['DISABLED_FEATURES'].to_s.exclude?('parliament_vote_app')
      namespace :parliament_vote_app, path: 'parlamentne-volby' do
        resource :application_forms, path: '' do
          member do
            get :end, path: 'volte-zodpovedne'
            get :home, path: 'hlasovanie-v-mieste-trvaleho-bydliska'
            get :person, path: 'hlasovaci-preukaz-osobne'
            get :non_sk_nationality, path: 'hlasovanie-neobcana'
            get :delivery, path: 'hlasovaci-preukaz'
            post :delivery, path: 'hlasovaci-preukaz'
            get :world, path: 'hlasovanie-v-zahranici'
            post :world, path: 'hlasovanie-v-zahranici'
          end
        end
      end
    end

    namespace :child_birth_app, path: 'narodenie-dietata' do
      get :picking_up_protocol, to: 'picking_up_protocol#show', path: 'vyzdvihnutie-rodneho-listu'
    end
  end
  resources :apps, path: 'aplikacie' # faux route

  resources :user_journeys, path: 'moje-zivotne-situacie' do
    post :restart, on: :member, path: 'zacat-odznova'
  end

  resources :notification_subscription_groups, controller: :notification_subscriptions, path: 'notifikacie' do
    get :confirm, on: :member, path: 'potvrdit'
  end

  resource :session, only: [:new, :create, :destroy]
  get '/auth/magiclink/info', to: 'sessions#magic_link_info'
  get '/auth/failure', to: 'sessions#failure'
  get '/auth/:provider/callback', to: 'sessions#create', as: :auth_callback
  get '/auth/:provider', to: lambda { |_| [404, {}, ["Not Found"]] }, as: :auth

  resources :faqs, path: 'casto-kladene-otazky'
  resources :pages, path: '', only: 'show'
  resources :feedbacks, path: 'spatna-vazba'
end
