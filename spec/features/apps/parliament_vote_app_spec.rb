require 'rails_helper'
require_relative '../../../app/models/apps/ep_vote_app/application_form'

def start
  visit apps_parliament_vote_app_application_forms_path
  click_button 'Súhlasím a chcem začať'
end

RSpec.feature "Parliament vote app", type: :feature do
  before do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::VOTE_DATE - 2.months
  end

  scenario 'As a citizen I want to request voting permit via post' do
    start

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    choose 'Poštou'
    click_button 'Pokračovať'

    fill_in 'Meno, priezvisko, titul', with: 'Ferko Mrkva'
    fill_in 'Rodné číslo', with: '123'
    fill_in 'Ulica', with: 'Pupavova 31'
    fill_in 'PSČ', with: '456'
    fill_in 'Obec', with: 'Bratislava - Karlova ves'
    click_button 'Pokračovať'

    choose 'Na adresu trvalého bydliska'
    click_button 'Pokračovať'

    expect(page).to have_content('Meno: Ferko Mrkva')
    expect(page).to have_content('Rodné číslo: 123')
    expect(page).to have_content('Trvalý pobyt: Pupavova 31, 456 Bratislava - Karlova ves')

    click_link 'pokračujte ďalej'
    expect(page).to have_content('Gratulujeme')
  end

  scenario 'As a citizen I want to request voting permit via post to a different address' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    choose 'Poštou'
    click_button 'Pokračovať'

    fill_in 'Meno, priezvisko, titul', with: 'Ferko Mrkva'
    fill_in 'Rodné číslo', with: '123'
    fill_in 'Ulica', with: 'Pupavova 31'
    fill_in 'PSČ', with: '456'
    fill_in 'Obec', with: 'Bratislava - Karlova ves'
    click_button 'Pokračovať'

    choose 'Na inú adresu'
    fill_in 'Ulica', with: 'Konvalinkova 3'
    fill_in 'PSČ', with: '456'
    fill_in 'Obec', with: 'Bratislava - Ruzinov'
    fill_in 'Štát', with: 'Slovensko'
    click_button 'Pokračovať'

    expect(page).to have_content('Meno: Ferko Mrkva')
    expect(page).to have_content('Rodné číslo: 123')
    expect(page).to have_content('Trvalý pobyt: Pupavova 31, 456 Bratislava - Karlova ves')

    expect(page).to have_content('Preukaz prosím zaslať na korešpondenčnú adresu: Konvalinkova 3, 456 Bratislava - Ruzinov, Slovensko')

    click_link 'pokračujte ďalej'
    expect(page).to have_content('Gratulujeme')
  end

  scenario 'As a citizen I want to request voting permit personally after the deadline' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::PICKUP_DEADLINE_DATE + 1.day
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    expect(page).to have_field('Osobne na úrade', disabled: true)
  end

  scenario 'As a citizen I want to request voting permit by authorized person after the deadline' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::PICKUP_DEADLINE_DATE + 1.day
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    expect(page).to have_field('Vyzdvihne ho za mňa iná osoba', disabled: true)
  end

  scenario 'As a citizen I want to request voting permit by post after the deadline' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::DELIVERY_BY_POST_DEADLINE_DATE + 1.day
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    expect(page).to have_field('Poštou', disabled: true)
  end

  scenario 'As a pernament citizen with I want to vote by post after the deadline' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::VOTE_BY_POST_DEADLINE_DATE + 1.day
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'V zahraničí'
    click_button 'Pokračovať'

    expect(page).to have_content('Termín na zaslanie žiadosti o voľbu poštou uplynul 10. januára')
  end

  scenario 'As a abroad citizen I want to vote by post after the deadline' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::VOTE_BY_POST_DEADLINE_DATE + 1.day
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Nie, mám odhlásený trvalý pobyt zo Slovenska'
    click_button 'Pokračovať'

    expect(page).to have_content('Termín na zaslanie žiadosti o voľbu poštou uplynul 10. januára')
  end

  scenario 'As a citizen I want to request voting permit personally' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    choose 'Osobne'
    click_button 'Pokračovať'

    expect(page).to have_content('Prevzatie hlasovacieho preukazu osobne')
  end

  scenario 'As a citizen I want to request voting permit via authorized person' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, mimo trvalého bydliska'
    click_button 'Pokračovať'

    choose 'Vyzdvihne ho za mňa iná osoba'
    click_button 'Pokračovať'

    fill_in 'Meno, priezvisko, titul', with: 'Ferko Mrkva', class: 'person'
    fill_in 'Rodné číslo', with: '123', class: 'person'
    fill_in 'Ulica', with: 'Pupavova 31'
    fill_in 'PSČ', with: '456'
    fill_in 'Obec', with: 'Bratislava - Karlova ves'
    fill_in 'Meno, priezvisko, titul', with: 'Jarko Mrkva', class: 'authorized-person'
    fill_in 'Číslo občianskeho preukazu', with: '567', class: 'authorized-person'
    click_button 'Pokračovať'

    expect(page).to have_content('Meno: Ferko Mrkva')
    expect(page).to have_content('Rodné číslo: 123')
    expect(page).to have_content('Trvalý pobyt: Pupavova 31, 456 Bratislava - Karlova ves')
    expect(page).to have_content('Preukaz vyzdvihne splnomocnená osoba: Meno: Jarko Mrkva Číslo občianskeho preukazu: 567')

    click_link 'pokračujte ďalej'
    expect(page).to have_content('Gratulujeme')
  end

  scenario 'As a citizen I want to vote at home address' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Na Slovensku, v mieste trvalého bydliska'
    click_button 'Pokračovať'

    expect(page).to have_content('Nepotrebujete nič vybavovať')
  end

  scenario 'As a citizen I want to vote in foregin country with permanent residency in Slovakia' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Áno'
    click_button 'Pokračovať'

    choose 'V zahraničí'
    click_button 'Pokračovať'

    expect(page).to have_content('Žiadosť o voľbu poštou pre voľby do Národnej rady Slovenskej republiky je potrebné doručiť svojej obci v mieste trvalého bydliska najneskôr do 50 dní pred dňom konania volieb')

    fill_in 'Meno, priezvisko, titul', with: 'Ferko Mrkva'
    fill_in 'Rodné číslo', with: '123'
    fill_in 'Ulica', with: 'Pupavova 31', class: 'pernament-address'
    fill_in 'PSČ', with: '456', class: 'pernament-address'
    fill_in 'Obec', with: 'Bratislava - Karlova ves', class: 'pernament-address'
    fill_in 'Ulica', with: 'Polk 1700', class: 'delivery-address'
    fill_in 'PSČ', with: '94109', class: 'delivery-address'
    fill_in 'Obec', with: 'San Francisco', class: 'delivery-address'
    fill_in 'Štát', with: 'California, USA', class: 'delivery-address'
    click_button 'Pokračovať'

    expect(page).to have_content('Meno: Ferko Mrkva')
    expect(page).to have_content('Rodné číslo: 123')
    expect(page).to have_content('Ulica: Pupavova 31')
    expect(page).to have_content('Obec: Bratislava - Karlova ves')
    expect(page).to have_content('PSČ: 94109')
    expect(page).to have_content('Ulica: Polk 1700')
    expect(page).to have_content('Obec: San Francisco')
    expect(page).to have_content('PSČ: 94109')
    expect(page).to have_content('Štát: California, USA')
    expect(page).to have_content('Zároveň Vás žiadam o potvrdenie prijatia tejto žiadosti.')
  end

  scenario 'As a citizen I want to vote in foregin country with permanent residency outside Slovakia' do
    start
    choose 'Áno'
    click_button 'Pokračovať'

    choose 'Nie, mám odhlásený trvalý pobyt zo Slovenska'
    click_button 'Pokračovať'

    expect(page).to have_content('Žiadosť o voľbu poštou pre voľby do Národnej rady Slovenskej republiky je potrebné doručiť na Ministerstvo vnútra najneskôr do 50 dní pred dňom konania volieb')

    fill_in 'Meno, priezvisko, titul', with: 'Ferko Mrkva'
    fill_in 'Rodné číslo', with: '123'
    fill_in 'Ulica', with: 'Polk 1700'
    fill_in 'PSČ', with: '94109'
    fill_in 'Obec', with: 'San Francisco'
    fill_in 'Štát', with: 'California, USA'
    click_button 'Pokračovať'

    expect(page).to have_content('Meno: Ferko Mrkva')
    expect(page).to have_content('Rodné číslo: 123')
    expect(page).to have_content('Ulica: Polk 1700')
    expect(page).to have_content('Obec: San Francisco')
    expect(page).to have_content('PSČ: 94109')
    expect(page).to have_content('Štát: California, USA')
    expect(page).to have_content('Zároveň Vás žiadam o potvrdenie prijatia tejto žiadosti.')
  end

  scenario "As a non-SK citizen I can't vote in parliament votes" do
    start
    choose 'Nie'
    click_button 'Pokračovať'

    expect(page).to have_content('môžu voliť len občania Slovenskej republiky.')
  end

  scenario 'As a citizen I want to see subscription options when vote is not active' do
    travel_to Apps::ParliamentVoteApp::ApplicationForm::VOTE_DATE + 1.day
    visit apps_parliament_vote_app_application_forms_path

    expect(page).to have_content('Voľby do parlamentu sa už konali')
    expect(page).to have_content('Chcem dostávať upozornenia k voľbám')
  end
end
