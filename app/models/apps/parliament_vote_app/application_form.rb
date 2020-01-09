module Apps
  module ParliamentVoteApp
    class ApplicationForm
      VOTE_DATE = Date.new(2020, 2, 29)
      DELIVERY_BY_POST_DEADLINE_DATE = VOTE_DATE - 15.days
      STATE_KEY = ('%s-state' % self.to_s.parameterize).freeze
      STEP_DEPENDENCIES = ActiveSupport::HashWithIndifferentAccess.new({
          start: [],
          sk_citizen: [:start], # -> permanent_resident, non_sk_nationality
          permanent_resident: [:sk_citizen], # -> place, world_abroad_permanent_resident
          place: [:permanent_resident], # -> delivery, home, world_sk_permanent_resident
          world_abroad_permanent_resident: [:permanent_resident], # -> world_abroad_permanent_resident_end
          world_abroad_permanent_resident_end: [:world_abroad_permanent_resident], # -> end
          world_sk_permanent_resident: [:place], # -> world_sk_permanent_resident_end
          world_sk_permanent_resident_end: [:world_sk_permanent_resident], # -> end
          delivery: [:place], # -> identity, person, authorized_person
          authorized_person: [:delivery], # -> authorized_person_send
          authorized_person_send: [:authorized_person], # -> end
          person: [:delivery], # none
          identity: [:delivery], # -> delivery_address
          delivery_address: [:identity], # -> send,
          send: [:delivery_address], # -> end
          end: [:send, :authorized_person_send, :world_sk_permanent_resident_end, :world_abroad_permanent_resident_end]
      })

      include ActiveModel::Model

      attr_accessor :step
      attr_accessor :place
      attr_accessor :sk_citizen
      attr_accessor :permanent_resident
      attr_accessor :delivery
      attr_accessor :full_name, :pin
      attr_accessor :authorized_person_full_name, :authorized_person_pin
      attr_accessor :street, :pobox, :municipality
      attr_accessor :same_delivery_address
      attr_accessor :delivery_street, :delivery_pobox, :delivery_municipality, :delivery_country
      attr_accessor :municipality_email
      attr_accessor :municipality_email_verified
      attr_accessor :back

      validates_presence_of :place, message: 'Vyberte si jednu z možností', on: :place

      validates_presence_of :sk_citizen, message: 'Vyberte áno pokiaľ ste občan Slovenskej republiky', on: :sk_citizen
      validates_presence_of :permanent_resident, message: 'Vyberte áno pokiaľ máte trvalý pobyt na Slovensku', on: :permanent_resident

      validates_presence_of :delivery, message: 'Vyberte si spôsob prevzatia hlasovacieho preukazu', on: :delivery
      validates_exclusion_of :delivery, in: ['post'],
                            if: -> { Date.current > DELIVERY_BY_POST_DEADLINE_DATE },
                             message: 'Termín na zaslanie hlasovacieho preukazu poštou už uplynul.', on: :delivery

      validates_presence_of :full_name, message: 'Meno je povinná položka',
                            on: [:identity, :world_sk_permanent_resident, :world_abroad_permanent_resident, :authorized_person]
      validates_presence_of :pin, message: 'Rodné číslo je povinná položka',
                            on: [:identity, :world_sk_permanent_resident, :world_abroad_permanent_resident, :authorized_person]
      validates_presence_of :street, message: 'Zadajte ulicu alebo názov obce ak obec nemá ulice',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :pobox, message: 'Zadajte poštové smerové čislo',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :municipality, message: 'Vyberte obec',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]

      validates_presence_of :authorized_person_full_name, message: 'Meno splnomocnenej osoby je povinná položka',
                            on: [:authorized_person]
      validates_presence_of :authorized_person_pin, message: 'Číslo občianskeho preukazu splnomocnenej osoby je povinná položka',
                            on: [:authorized_person]

      validates_presence_of :same_delivery_address, message: 'Zadajte kam chcete zaslať hlasovací preukaz',
                            on: :delivery_address
      validates_presence_of :delivery_street, message: 'Zadajte ulicu alebo názov obce ak obec nemá ulice',
                            on: [:delivery_address, :world_sk_permanent_resident, :world_abroad_permanent_resident],
                            if: -> (f) { f.custom_delivery_address? }
      validates_presence_of :delivery_pobox, message: 'Zadajte poštové smerové čislo',
                            on: [:delivery_address, :world_sk_permanent_resident, :world_abroad_permanent_resident],
                            if: -> (f) { f.custom_delivery_address? }
      validates_presence_of :delivery_municipality, message: 'Zadajte obec',
                            on: [:delivery_address, :world_sk_permanent_resident, :world_abroad_permanent_resident],
                            if: -> (f) { f.custom_delivery_address? }
      validates_presence_of :delivery_country, message: 'Zadajte štát',
                            on: [:delivery_address, :world_sk_permanent_resident, :world_abroad_permanent_resident],
                            if: -> (f) { f.custom_delivery_address? }

      def self.active?
        VOTE_DATE >= Date.current
      end

      def minv_email
        "volby@minv.sk"
      end

      def year
        VOTE_DATE.year
      end

      def custom_delivery_address?
        same_delivery_address == '0' || step == 'world_abroad_permanent_resident'
      end

      def municipality_email_verified?
        municipality_email_verified == "OK"
      end

      def full_address
        "#{street}, #{pobox} #{municipality}"
      end

      def go_back?
        back == "true"
      end

      def from_slovakia_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/from_slovakia_email_body",
          locals: { model: self },
        )
      end

      def from_slovakia_authorized_person_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/from_slovakia_authorized_person_email_body",
          locals: { model: self },
        )
      end

      def world_abroad_resident_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/world_abroad_resident_email_body",
          locals: { model: self },
        )
      end

      def world_sk_resident_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/world_sk_resident_email_body",
          locals: { model: self },
        )
      end

      def run(listener)
        case step
        when 'start'
          start_step(listener)
        when 'place'
          place_step(listener)
        when 'sk_citizen'
          sk_citizen_step(listener)
        when 'permanent_resident'
          permanent_resident_step(listener)
        when 'delivery'
          delivery_step(listener)
        when 'identity'
          identity_step(listener)
        when 'authorized_person'
          authorized_person_step(listener)
        when 'address'
          address_step(listener)
        when 'delivery_address'
          delivery_address_step(listener)
        when 'world_sk_permanent_resident'
          world_sk_permanent_resident_step(listener)
        when 'world_sk_permanent_resident_end'
          world_sk_permanent_resident_end_step(listener)
        when 'world_abroad_permanent_resident'
          world_abroad_permanent_resident_step(listener)
        when 'world_abroad_permanent_resident_end'
          world_abroad_permanent_resident_end_step(listener)
        end
      end

      def allowed_step?(step)
        dependencies = STEP_DEPENDENCIES.fetch(step, [])
        return true if dependencies.empty?
        
        result = dependencies.map do |dependent_step|
          valid?(dependent_step) && allowed_step?(dependent_step)
        end
        result.any?
      end

      private def start_step(listener)
        self.step = 'sk_citizen'
        listener.redirect_to_step :sk_citizen
      end

      private def sk_citizen_step(listener)
        if valid?(:sk_citizen)
          case sk_citizen
          when 'yes'
            self.step = 'permanent_resident'
            listener.redirect_to_step :permanent_resident
          when 'no'
            listener.redirect_to_step :non_sk_nationality
          end
        else
          listener.render_form
        end
      end

      private def place_step(listener)
        if go_back?
          self.step = 'permanent_resident'
          listener.redirect_to_step :permanent_resident
        elsif valid?(:place)
          case place
          when 'home'
            listener.redirect_to_step :home
          when 'sk'
            listener.redirect_to_step :delivery
          when 'world'
            self.step = 'world_sk_permanent_resident'
            listener.redirect_to_step :world_sk_permanent_resident
          end
        else
          listener.render_form
        end
      end

      # Home flow
      private def delivery_step(listener)
        if valid?(:delivery)
          case delivery
          when 'post'
            self.step = 'identity'
            listener.redirect_to_step :identity
          when 'authorized_person'
            self.step = 'authorized_person'
            listener.redirect_to_step :authorized_person
          when 'person'
            listener.redirect_to_step :person
          end
        else
          listener.render_form
        end
      end

      private def identity_step(listener)
        if go_back?
          self.step = 'delivery'
          listener.redirect_to_step :delivery
        elsif valid?(:identity)
          self.step = 'delivery_address'
          listener.redirect_to_step :delivery_address
        else
          listener.render_form
        end
      end

      private def delivery_address_step(listener)
        if go_back?
          self.step = 'identity'
          listener.redirect_to_step :identity
        elsif valid?(:delivery_address)
          self.step = 'send'
          listener.redirect_to_step :to_send
        else
          listener.render_form
        end
      end

      private def authorized_person_step(listener)
        if go_back?
          self.step = 'delivery'
          listener.redirect_to_step :delivery
        elsif valid?(:authorized_person)
          listener.redirect_to_step :authorized_person_send
        else
          self.step = 'authorized_person'
          listener.render_form
        end
      end

      private def permanent_resident_step(listener)
        if valid?(:permanent_resident)
          case permanent_resident
          when 'yes'
            self.step = 'place'
            listener.redirect_to_step :place
          when 'no'
            self.step = 'world_abroad_permanent_resident'
            listener.redirect_to_step :world_abroad_permanent_resident
          end
        else
          listener.render_form
        end
      end

      private def world_sk_permanent_resident_step(listener)
        if go_back?
          self.step = 'place'
          listener.redirect_to_step :place
        elsif valid?(:world_sk_permanent_resident)
          self.step = 'world_sk_permanent_resident_end'
          listener.redirect_to_step :world_sk_permanent_resident_end
        else
          listener.render_form
        end
      end

      private def world_sk_permanent_resident_end_step(listener)
        self.step = 'world_sk_permanent_resident_end'
        listener.redirect_to_step :world_sk_permanent_resident_end
      end

      private def world_abroad_permanent_resident_step(listener)
        if go_back?
          self.step = 'permanent_resident'
          listener.redirect_to_step :permanent_resident
        elsif valid?(:world_abroad_permanent_resident)
          self.step = 'world_abroad_permanent_resident_end'
          listener.redirect_to_step :world_abroad_permanent_resident_end
        else
          listener.render_form
        end
      end

      private def world_abroad_permanent_resident_end_step(listener)
        self.step = 'world_abroad_permanent_resident_end'
        listener.redirect_to_step :world_abroad_permanent_resident_end
      end
    end
  end
end
