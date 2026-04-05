require 'logger'
require 'fileutils'
require 'net/http'
require 'json'
require 'uri'

module Valhalla
  module Actions
    class NotifyOwner < Ruflow::Action
      set_options(
        input:  '*',
        output: { ok: '*' }
      )

      RESEND_URI = URI('https://api.resend.com/emails')

      def start(lead)
        priority_tag  = lead[:priority] == :high ? '*** HIGH PRIORITY ***' : '[standard]'
        service_label = lead[:service].to_s.upcase.tr('-_', ' ')
        service_label = 'Not specified' if service_label.empty?

        log_message = <<~MSG
          #{priority_tag}  New Stonevell Lead
          ─────────────────────────────────────
          ID:       #{lead[:id]}
          Name:     #{lead[:name]}
          Email:    #{lead[:email]}
          Phone:    #{lead[:phone].to_s.empty? ? 'N/A' : lead[:phone]}
          Service:  #{service_label}
          Score:    #{lead[:score]} / 100
          Message:  #{lead[:message].to_s.empty? ? '(none)' : lead[:message]}
          Received: #{lead[:received_at]}
          ─────────────────────────────────────
        MSG

        logger.info(log_message)
        $stdout.puts("\n#{log_message}") if $stdout.isatty

        send_email(lead, priority_tag, service_label)

        [:ok, lead]
      end

      private

      def send_email(lead, priority_tag, service_label)
        subject = "#{priority_tag} New Lead: #{lead[:name]} — #{service_label}"

        html_body = <<~HTML
          <div style="font-family:monospace;background:#0a0a0a;color:#f0ece4;padding:24px;border-radius:8px;max-width:600px;">
            <div style="color:#c9a84c;font-size:18px;font-weight:bold;margin-bottom:16px;">
              #{lead[:priority] == :high ? '&#9889; HIGH PRIORITY' : '&#128139; New Lead'} &mdash; Stonevell Valhalla
            </div>
            <table style="width:100%;border-collapse:collapse;">
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;width:80px;">Name</td><td style="color:#f0ece4;padding:4px 0;">#{lead[:name]}</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Email</td><td style="color:#c9a84c;padding:4px 0;">#{lead[:email]}</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Phone</td><td style="color:#f0ece4;padding:4px 0;">#{lead[:phone].to_s.empty? ? 'N/A' : lead[:phone]}</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Service</td><td style="color:#f0ece4;padding:4px 0;">#{service_label}</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Score</td><td style="color:#f0ece4;padding:4px 0;">#{lead[:score]} / 100</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Message</td><td style="color:#f0ece4;padding:4px 0;">#{lead[:message].to_s.empty? ? '(none)' : lead[:message]}</td></tr>
              <tr><td style="color:#7a746a;padding:4px 8px 4px 0;">Received</td><td style="color:#f0ece4;padding:4px 0;">#{lead[:received_at]}</td></tr>
            </table>
          </div>
        HTML

        http = Net::HTTP.new(RESEND_URI.host, RESEND_URI.port)
        http.use_ssl = true

        req = Net::HTTP::Post.new(RESEND_URI)
        req['Authorization'] = "Bearer #{CONFIG[:resend_api_key]}"
        req['Content-Type']  = 'application/json'
        req.body = JSON.generate(
          from:    CONFIG[:from_email],
          to:      [CONFIG[:owner_email]],
          subject: subject,
          html:    html_body
        )

        res = http.request(req)
        logger.info("Email sent → #{res.code} #{res.message}")
      rescue => e
        logger.error("Email failed: #{e.message}")
      end

      def logger
        @logger ||= begin
          FileUtils.mkdir_p(CONFIG[:data_dir])
          log_path = File.join(CONFIG[:data_dir], 'leads.log')
          l = Logger.new(log_path, 'daily')
          l.formatter = proc { |_, _, _, msg| "#{msg}\n" }
          l
        end
      end
    end
  end
end
