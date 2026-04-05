require 'logger'
require 'fileutils'

module Valhalla
  module Actions
    class RejectLead < Ruflow::Action
      set_options(
        input:  '*',
        output: { rejected: '*' }
      )

      def start(lead)
        logger.warn("Rejected — email=#{lead[:email].inspect}  errors=#{lead[:errors]&.join(', ')}")
        [:rejected, lead]
      end

      private

      def logger
        @logger ||= begin
          FileUtils.mkdir_p(CONFIG[:data_dir])
          log_path = File.join(CONFIG[:data_dir], 'leads.log')
          l = Logger.new(log_path, 'daily')
          l.formatter = proc { |sev, _, _, msg| "[#{sev}] #{msg}\n" }
          l
        end
      end
    end
  end
end
