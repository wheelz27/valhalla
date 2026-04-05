require 'net/http'
require 'uri'
require 'json'

module Valhalla
  module StripeClient

    BASE = 'https://api.stripe.com/v1'

    def self.request(method, path, params = {})
      uri  = URI("#{BASE}#{path}")
      key  = CONFIG[:stripe_secret_key]

      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.read_timeout = 10

      req = case method
            when :get
              uri.query = URI.encode_www_form(params) unless params.empty?
              Net::HTTP::Get.new(uri)
            when :post
              r = Net::HTTP::Post.new(uri)
              r.set_form_data(flatten_params(params))
              r
            end

      req['Authorization']  = "Bearer #{key}"
      req['Stripe-Version'] = '2023-10-16'

      res  = http.request(req)
      body = JSON.parse(res.body, symbolize_names: true)

      unless res.is_a?(Net::HTTPSuccess)
        raise "Stripe error #{res.code}: #{body.dig(:error, :message)}"
      end

      body
    end

    # ── Create a Checkout Session ────────────────────────────────
    def self.create_checkout_session(line_items:, customer_email: nil, metadata: {})
      params = {
        'mode'                  => 'payment',
        'success_url'           => "#{CONFIG[:site_url]}/payment-success.html?session_id={CHECKOUT_SESSION_ID}",
        'cancel_url'            => "#{CONFIG[:site_url]}/contact.html",
        'payment_method_types[]' => 'card'
      }

      params['customer_email'] = customer_email if customer_email

      line_items.each_with_index do |item, i|
        params["line_items[#{i}][price_data][currency]"]                        = 'usd'
        params["line_items[#{i}][price_data][product_data][name]"]              = item[:name]
        params["line_items[#{i}][price_data][product_data][description]"]       = item[:description] || ''
        params["line_items[#{i}][price_data][unit_amount]"]                     = item[:amount_cents].to_s
        params["line_items[#{i}][quantity]"]                                    = (item[:quantity] || 1).to_s
      end

      metadata.each { |k, v| params["metadata[#{k}]"] = v.to_s }

      request(:post, '/checkout/sessions', params)
    end

    # ── Create a Payment Link (reusable) ─────────────────────────
    def self.create_price(name:, amount_cents:, currency: 'usd')
      product = request(:post, '/products', { name: name })
      request(:post, '/prices', {
        product:     product[:id],
        unit_amount: amount_cents,
        currency:    currency
      })
    end

    # ── Retrieve a completed session ─────────────────────────────
    def self.retrieve_session(session_id)
      request(:get, "/checkout/sessions/#{session_id}")
    end

    private

    def self.flatten_params(hash, prefix = nil)
      hash.each_with_object({}) do |(k, v), result|
        key = prefix ? "#{prefix}[#{k}]" : k.to_s
        if v.is_a?(Hash)
          result.merge!(flatten_params(v, key))
        else
          result[key] = v
        end
      end
    end

  end
end
