require 'rails_helper'
require_relative '../../app/models/apps/ep_vote_app/application_form'

RSpec.feature "Notification subscriptions", type: :feature do
  let!(:user) {create(:user, email: 'someone@example.com')}
  let!(:blank_journey) {create(:journey, published_status: "BLANK", description: nil)}

  def sign_in(user)
    OmniAuth.config.test_mode = false
    visit new_session_path

    within 'form#login-email' do
      fill_in :email, with: user.email
    end

    click_on 'Prihlásiť sa e-mailom'

    visit link_in_last_email
  end

  before do
    # https://stackoverflow.com/questions/598933/how-do-i-change-the-default-www-example-com-domain-for-testing-in-rails
    default_url_options[:host] = "localhost:3000"
    Capybara.default_host = "http://localhost:3000"
    allow(Apps::EpVoteApp::ApplicationForm).to receive(:active?).and_return(true)
  end

  scenario 'As a visitor I want to subscribe to various notifications' do
    expect(SubscribeSendinblueJob).to receive(:perform_later).with('johno@jsmf.net', 'VoteSubscription')

    visit apps_ep_vote_app_application_forms_path

    click_button 'Súhlasím a chcem začať'

    choose 'V zahraničí'
    click_button 'Pokračovať'

    check 'Chcem dostávať upozornenia k voľbám'

    fill_in 'Emailová adresa', with: 'johno@jsmf.net'

    click_button 'Chcem dostávať tieto notifikácie'

    visit link_in_last_email

    expect(page).to have_content('Úspešne ste si aktivovali tieto notifikácie')
    expect(page).to have_content('Chcem dostávať upozornenia k voľbám')
  end

  scenario 'As a logged in user I want to subscribe to various notifications' do
    expect(SubscribeSendinblueJob).to receive(:perform_later).with('someone@example.com', 'VoteSubscription')

    sign_in user
    visit apps_ep_vote_app_application_forms_path

    click_button 'Súhlasím a chcem začať'

    choose 'V zahraničí'
    click_button 'Pokračovať'

    check 'Chcem dostávať upozornenia k voľbám'

    clear_mail_deliveries

    click_button 'Chcem dostávať tieto notifikácie'

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  scenario 'As an anonymous user I want to subscribe to blank journey notification' do
    visit journey_path(blank_journey)

    check 'Chcem odoberať informácie k tomuto návodu'

    fill_in 'Emailová adresa', with: 'example@email.com'

    click_button 'Chcem dostávať tieto notifikácie'

    visit link_in_last_email

    expect(page).to have_content('Úspešne ste si aktivovali tieto notifikácie')
  end

  scenario 'As a logged user I want to subscribe to blank journey notification' do
    sign_in(user)
    visit journey_path(blank_journey)

    check 'Chcem odoberať informácie k tomuto návodu'

    clear_mail_deliveries

    click_button 'Chcem dostávať tieto notifikácie'

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  scenario 'I visit a page to see possible subscriptions' do
    visit notification_subscription_groups_path

    expect(page).to have_content('Aktivujte si užitočné notifikácie na email')
  end
end
