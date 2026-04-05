require 'sinatra'
require 'sinatra/json'
require 'rack/cors'
require 'json'
require_relative 'lib/valhalla'
require_relative 'lib/stripe_client'

configure do
  set :port,            (ENV['PORT'] || 4567).to_i
  set :bind,            '0.0.0.0'
  set :show_exceptions, false
end

use Rack::Cors do
  allow do
    origins '*'
    resource '/leads',           headers: :any, methods: [:get, :post, :options]
    resource '/checkout',        headers: :any, methods: [:post, :options]
    resource '/session',         headers: :any, methods: [:get, :options]
    resource '/webhook/stripe',  headers: :any, methods: [:post]
    resource '/health',          headers: :any, methods: [:get]
  end
end

# ── Stonevell service menu (cents) ───────────────────────────
SERVICES = {
  'diagnostic'    => { name: 'PC / Mac Diagnostic',           amount: 4900  },
  'virus_removal' => { name: 'Virus & Malware Removal',        amount: 7900  },
  'setup'         => { name: 'New Device Setup',               amount: 9900  },
  'networking'    => { name: 'Network Setup & Configuration',  amount: 14900 },
  'data_recovery' => { name: 'Data Recovery',                  amount: 19900 },
  'remote_hour'   => { name: 'Remote Support (1 hour)',        amount: 7500  },
  'onsite_hour'   => { name: 'On-Site Support (1 hour)',       amount: 9500  },
  'custom'        => { name: 'Custom Service',                 amount: nil   }
}.freeze

# ── Health check ─────────────────────────────────────────────
get '/health' do
  json status: 'ok', system: 'Valhalla', version: '1.0.0'
end

# ── Inbound lead from contact form ───────────────────────────
post '/leads' do
  raw    = request.body.read
  params = JSON.parse(raw, symbolize_names: true) rescue {}

  lead = {
    name:    params[:name],
    email:   params[:email],
    phone:   params[:phone],
    service: params[:service],
    message: params[:message]
  }

  flow            = Valhalla::Flows::LeadIntakeFlow.with_custom_options(default_input: lead)
  output_port, result = flow.start

  if output_port == :ok
    status 200
    json success: true,
         id:       result[:id],
         priority: result[:priority].to_s,
         score:    result[:score]
  else
    status 422
    json success: false,
         message:  'Submission could not be processed',
         errors:   result[:errors]
  end

rescue => e
  $stderr.puts "Valhalla error: #{e.class} — #{e.message}\n#{e.backtrace.first(3).join("\n")}"
  status 500
  json success: false, message: 'Server error — please call 775-484-3804'
end

# ── View captured leads (local admin) ────────────────────────
get '/leads' do
  path  = File.join(__dir__, 'data', 'leads.json')
  leads = File.exist?(path) ? JSON.parse(File.read(path)) : []
  json leads
end

# ── Create Stripe Checkout Session ───────────────────────────
post '/checkout' do
  raw    = request.body.read
  params = JSON.parse(raw, symbolize_names: true) rescue {}

  service_key = params[:service].to_s
  svc         = SERVICES[service_key]

  unless svc
    status 400
    next json success: false, message: "Unknown service: #{service_key}"
  end

  # Allow custom amount (in dollars) for custom jobs
  amount_cents = if service_key == 'custom'
    dollars = params[:amount].to_f
    if dollars <= 0
      status 400
      next json success: false, message: 'Amount required for custom service'
    end
    (dollars * 100).to_i
  else
    svc[:amount]
  end

  session = Valhalla::StripeClient.create_checkout_session(
    line_items: [{
      name:         svc[:name],
      description:  params[:description].to_s,
      amount_cents: amount_cents,
      quantity:     (params[:quantity] || 1).to_i
    }],
    customer_email: params[:email],
    metadata: {
      client_name:  params[:name],
      client_phone: params[:phone],
      service:      service_key
    }
  )

  status 200
  json success: true, checkout_url: session[:url], session_id: session[:id]

rescue => e
  $stderr.puts "Stripe checkout error: #{e.message}"
  status 500
  json success: false, message: 'Payment setup failed — please call 775-484-3804'
end

# ── Retrieve completed session (for success page) ────────────
get '/session' do
  sid = params[:id].to_s.strip

  if sid.empty?
    status 400
    next json success: false, message: 'Missing session id'
  end

  session = Valhalla::StripeClient.retrieve_session(sid)

  status 200
  json success:        true,
       customer_email: session[:customer_details]&.dig(:email),
       amount_total:   session[:amount_total],
       currency:       session[:currency],
       payment_status: session[:payment_status],
       service:        session.dig(:metadata, :service)

rescue => e
  $stderr.puts "Session retrieve error: #{e.message}"
  status 500
  json success: false, message: 'Could not retrieve session'
end

# ── Stripe Webhook ────────────────────────────────────────────
post '/webhook/stripe' do
  payload   = request.body.read
  sig       = request.env['HTTP_STRIPE_SIGNATURE']
  secret    = ENV['STRIPE_WEBHOOK_SECRET']

  event = if secret && sig
    begin
      Valhalla::StripeClient.verify_webhook(payload, sig, secret)
    rescue => e
      $stderr.puts "Webhook signature failed: #{e.message}"
      status 400
      next json error: 'Invalid signature'
    end
  else
    JSON.parse(payload, symbolize_names: true) rescue {}
  end

  if event[:type] == 'checkout.session.completed'
    sess     = event.dig(:data, :object) || {}
    amount   = (sess[:amount_total].to_i / 100.0).round(2)
    email    = sess.dig(:customer_details, :email) || 'unknown'
    name     = sess.dig(:metadata, :client_name) || 'Client'
    service  = sess.dig(:metadata, :service) || 'service'
    phone    = sess.dig(:metadata, :client_phone) || ''

    # Log payment
    log_path = File.join(Valhalla::CONFIG[:data_dir], 'payments.log')
    File.open(log_path, 'a') do |f|
      f.puts "[#{Time.now}] PAID $#{amount} — #{name} (#{email}) — #{service}"
    end

    # Email notification
    require_relative 'lib/actions/notify_owner'
    Valhalla::Actions::NotifyOwner.new.call({
      name:    name,
      email:   email,
      phone:   phone,
      service: service,
      message: "💳 PAYMENT RECEIVED — $#{amount} USD\nService: #{service}\nClient: #{name}\nEmail: #{email}"
    })

    $stdout.puts "Payment received: $#{amount} from #{email}"
  end

  status 200
  json received: true
rescue => e
  $stderr.puts "Webhook error: #{e.message}"
  status 500
  json error: 'Webhook processing failed'
end
