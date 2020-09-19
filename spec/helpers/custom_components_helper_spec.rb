require 'rails_helper'

RSpec.describe CustomComponentsHelper, type: :helper do
  describe 'raw_with_custom_components' do
    describe '<embedded-app />' do
      it 'renders an embedded app' do
        result = helper.raw_with_custom_components('<embedded-app app-id="narodenie-rodny-list" />')
        parsed_result = Nokogiri(result)

        expect(result).to include "Slobodná"
        expect(parsed_result.root.name).to eq 'div'
        expect(parsed_result.root['data-embedded-app']).to eq 'narodenie-rodny-list'
      end

      it 'supports multiple occurences' do
        result = helper.raw_with_custom_components('<embedded-app app-id="narodenie-rodny-list" /><embedded-app app-id="narodenie-rodny-list" />')
        expect(Nokogiri(result).css('div[data-embedded-app="narodenie-rodny-list"]').size).to eq 2
      end

      it 'supports component being deeper' do
        result = helper.raw_with_custom_components('<div><embedded-app app-id="narodenie-rodny-list" /></div>')
        expect(result).to include "Slobodná"
      end
    end

    describe '<notification-subscription />' do
      before(:each) do
        @user = double(User, email: 'customer@test.sk', logged_in?: true)
        NotificationSubscriptionsHelper.module_eval { def current_user; @user; end }
      end

      it 'renders a notification subscription component with multiple checkboxes' do
        result = helper.raw_with_custom_components('<notification-subscription types="BlankJourneySubscription, NewsletterSubscription" />')

        expect(result).to include 'Zašleme Vám e-mail, keď vytvoríme tento návod alebo sa bude diať niečo relevantné.'
      end

      it 'renders a notification subscription component without checkboxes in case of only one subscription type' do
        result = helper.raw_with_custom_components('<notification-subscription types="NewsletterSubscription" />')

        expect(result).not_to include 'Zašleme Vám e-mail, keď vytvoríme tento návod alebo sa bude diať niečo relevantné.'
      end

      it 'supports multiple occurrences' do
        result = helper.raw_with_custom_components('<notification-subscription types="BlankJourneySubscription" /><notification-subscription types="BlankJourneySubscription" />')
        expect(Nokogiri(result).css('input[name="notification_subscription_group[subscriptions][]"]').size).to eq 2
        expect(Nokogiri(result).css('input[value="Chcem dostávať tieto notifikácie"]').size).to eq 2
      end

      it 'supports multiple types' do
        result = helper.raw_with_custom_components('<notification-subscription types="BlankJourneySubscription, NextVoteSubscription" />')
        expect(Nokogiri(result).css('input[name="notification_subscription_group[subscriptions][]"]').size).to eq 2
        expect(Nokogiri(result).css('input[value="Chcem dostávať tieto notifikácie"]').size).to eq 1
      end

      it 'does not break on typos and spaces' do
        result = helper.raw_with_custom_components('<notification-subscription types="BlankJourneySubscription, NextVoteSubscription, Bogus" />')
        expect(Nokogiri(result).css('input[name="notification_subscription_group[subscriptions][]"]').size).to eq 2
        expect(Nokogiri(result).css('input[value="Chcem dostávať tieto notifikácie"]').size).to eq 1
      end

      it 'supports component being deeper' do
        result = helper.raw_with_custom_components('<notification-subscription types="BlankJourneySubscription, NewsletterSubscription" />')
        expect(result).to include 'Zašleme Vám e-mail, keď vytvoríme tento návod alebo sa bude diať niečo relevantné.'
      end
    end
  end
end
