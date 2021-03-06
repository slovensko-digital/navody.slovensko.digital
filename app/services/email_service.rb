class EmailService
  class << self
    def subscribe_to_newsletter(email, list_name)
      list = find_list(list_name)

      raise "Contact list not found: #{list_name}" unless list[:id]

      create_contact(email: email, listIds: [list[:id]], updateEnabled: true)
    end

    def send_email(params)
      email = SibApiV3Sdk::SendSmtpEmail.new(params)
      transactional_emails_api.send_transac_email(email)
    end

    private

    def create_contact(params)
      contacts_api.create_contact(params)
    end

    def find_list(name)
      options = {
        limit: 50,
        offset: 0
      }
      result = contacts_api.get_lists(options)
      total_pages = (result.count / options[:limit]) + 1

      total_pages.times do |n|
        matched = result.lists.detect { |i| i[:name] == name }
        return matched if matched
        return if (n + 1) == total_pages

        options[:offset] = (n + 1) * options[:limit]
        result = contacts_api.get_lists(options)
      end
    end

    def contacts_api
      SibApiV3Sdk::ContactsApi.new
    end

    def transactional_emails_api
      SibApiV3Sdk::TransactionalEmailsApi.new
    end
  end
end


