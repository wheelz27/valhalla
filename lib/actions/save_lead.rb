require 'json'
require 'fileutils'

module Valhalla
  module Actions
    class SaveLead < Ruflow::Action
      set_options(
        input:  '*',
        output: { ok: '*' }
      )

      def start(lead)
        dir  = CONFIG[:data_dir]
        FileUtils.mkdir_p(dir)
        path  = File.join(dir, 'leads.json')
        leads = File.exist?(path) ? JSON.parse(File.read(path), symbolize_names: true) : []

        # Convert symbols to strings for JSON serialization
        serializable = deep_stringify(lead)
        leads << serializable
        File.write(path, JSON.pretty_generate(leads))

        [:ok, lead]
      end

      private

      def deep_stringify(obj)
        case obj
        when Hash  then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
        when Array then obj.map { |v| deep_stringify(v) }
        when Symbol then obj.to_s
        else obj
        end
      end
    end
  end
end
