require 'rails_helper'

RSpec.feature "Feedback bar" do
  scenario 'clicking on positive feedback link shows appropriate form and close button works' do
    visit root_path
    expect(page).to have_content('Áno')
  end

  scenario 'clicking on negative feedback link shows appropriate form and close button works' do
    visit root_path
    click_on 'Nie'
    expect(page).to have_content('Pomôžte nám zlepšiť Návody.Digital')
  end

  scenario 'clicking on contact us shows up contact form and close button works' do
    visit root_path
    click_on 'Napíšte nám'
    expect(page).to have_content('Nahlásenie chyby')
  end
end

