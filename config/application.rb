require_relative 'boot'

require 'rails/all'
#require 'devkit'
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ElephantCharge
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += %W(#{config.root}/lib)
    config.active_record.time_zone_aware_types = [:datetime, :time]
    config.assets.precompile += %w(vendor/assets/images/*)
    config.active_record.schema_format = :sql
    config.time_zone = 'Africa/Harare'
  end
end


