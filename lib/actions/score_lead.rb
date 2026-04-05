module Valhalla
  module Actions
    class ScoreLead < Ruflow::Action
      set_options(
        input:  '*',
        output: { ok: '*' }
      )

      # Normalize dash/underscore variants from the HTML form
      SERVICE_SCORES = {
        'cybersecurity'  => 35,
        'ai-automation'  => 30,
        'ai_automation'  => 30,
        'managed-it'     => 25,
        'managed_it'     => 25,
        'device-repair'  => 20,
        'device_repair'  => 20,
        'web-presence'   => 15,
        'web_presence'   => 15
      }.freeze

      def start(lead)
        score = 25  # base

        score += SERVICE_SCORES.fetch(lead[:service].to_s, 10)
        score += 10 unless lead[:phone].to_s.strip.empty?
        score += 10 if lead[:message].to_s.length > 50
        score += 5  if lead[:message].to_s.length > 150
        score += 5  if lead[:email].to_s.match?(/\.(com|net|org|io|co)\z/i)

        priority = score >= 70 ? :high : :standard

        [:ok, lead.merge(score: score, priority: priority)]
      end
    end
  end
end
