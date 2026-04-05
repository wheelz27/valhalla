require 'securerandom'
require 'time'

module Valhalla
  module Actions
    class EnrichLead < Ruflow::Action
      set_options(
        input:  '*',
        output: { ok: '*' }
      )

      def start(lead)
        enriched = lead.merge(
          id:          SecureRandom.uuid,
          received_at: Time.now.iso8601,
          status:      :new,
          source:      'contact_form'
        )
        [:ok, enriched]
      end
    end
  end
end
