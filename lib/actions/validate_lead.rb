module Valhalla
  module Actions
    class ValidateLead < Ruflow::Action
      set_options(
        input:  '*',
        output: { valid: '*', rejected: '*' }
      )

      EMAIL_RE = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      def start(lead)
        errors = []
        errors << 'name is required'         if lead[:name].to_s.strip.empty?
        errors << 'email is required'        if lead[:email].to_s.strip.empty?
        errors << 'email format is invalid'  unless lead[:email].to_s.match?(EMAIL_RE)

        if errors.empty?
          [:valid, lead]
        else
          [:rejected, lead.merge(errors: errors)]
        end
      end
    end
  end
end
