module Valhalla
  CONFIG = {
    owner_email:       ENV.fetch('OWNER_EMAIL',    'mike@stonevell.com'),
    owner_phone:       ENV.fetch('OWNER_PHONE',    '775-484-3804'),
    resend_api_key:    ENV.fetch('RESEND_API_KEY'),
    from_email:        ENV.fetch('FROM_EMAIL',     'Valhalla <valhalla@stonevell.com>'),
    stripe_secret_key: ENV.fetch('STRIPE_SECRET_KEY'),
    stripe_pub_key:    ENV.fetch('STRIPE_PUB_KEY'),
    site_url:          ENV.fetch('SITE_URL',       'https://stonevell.com'),
    data_dir:          File.join(__dir__, 'data')
  }.freeze
end
