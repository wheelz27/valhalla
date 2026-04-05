module Valhalla
  module Flows
    # LeadIntakeFlow — The Valhalla System core pipeline
    #
    # Flow:  ValidateLead ─valid──► EnrichLead ──► ScoreLead ──► SaveLead ──► NotifyOwner
    #                      └rejected──► RejectLead
    #
    class LeadIntakeFlow < Ruflow::Flow
      set_options(
        input:  '*',
        output: { ok: '*', rejected: '*' }
      )

      set_actions({
        1 => { klass: Actions::ValidateLead, output_to: { valid: 2, rejected: 5 } },
        2 => { klass: Actions::EnrichLead,   output_to: { ok: 3 } },
        3 => { klass: Actions::ScoreLead,    output_to: { ok: 4 } },
        4 => { klass: Actions::SaveLead,     output_to: { ok: 6 } },
        5 => { klass: Actions::RejectLead },   # terminal — invalid leads
        6 => { klass: Actions::NotifyOwner }   # terminal — processed leads
      })

      set_start_action_id 1
    end
  end
end
