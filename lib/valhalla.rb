require 'ruflow'
require_relative '../config'

require_relative 'actions/validate_lead'
require_relative 'actions/enrich_lead'
require_relative 'actions/score_lead'
require_relative 'actions/save_lead'
require_relative 'actions/notify_owner'
require_relative 'actions/reject_lead'

require_relative 'flows/lead_intake_flow'
