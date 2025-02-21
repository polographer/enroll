# frozen_string_literal: true

Rails.application.configure do
  # Verifies that versions and hashed value of the package contents in the project's package.json
  config.webpacker.check_yarn_integrity = true
  config.session_store :cache_store


  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.cache_store = :memory_store

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
  config.webpacker.check_yarn_integrity = false

  # Raise an error on page load if there are pending migrations.
  # config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  config.acapi.publish_amqp_events = :log
  config.acapi.app_id = "enroll"
  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.action_mailer.default_url_options = {
    :host => "127.0.0.1",
    :port => 3000
  }

  config.action_cable.url = "ws://localhost:3000/cable"

  config.action_cable.allowed_request_origins = [%r{http://*},
                                                 %r{https://*}]

  #Environment URL stub
  config.checkbook_services_base_url = "https://checkbook_url"
  config.checkbook_services_ivl_path = "/ivl/"
  config.checkbook_services_shop_path = "/shop/"
  config.checkbook_services_congress_url = "https://checkbook_url/congress/"
  config.checkbook_services_remote_access_key = "9876543210"
  config.checkbook_services_reference_id = "0123456789"
  config.checkbook_services_environment_key = "local"
  # for Employer Auto Pay
  config.wells_fargo_api_url = 'https://demo.e-billexpress.com:443/PayIQ/Api/SSO'
  config.wells_fargo_api_key = 'e2dab122-114a-43a3-aaf5-78caafbbec02'
  config.wells_fargo_biller_key = '3741'
  config.wells_fargo_api_secret = 'dchbx 2017'
  config.wells_fargo_api_version = '3000'
  config.wells_fargo_private_key_location = '/wfpk.pem'
  config.wells_fargo_api_date_format = '%Y-%m-%dT%H:%M:%S.0000000%z'
  config.cartafact_document_base_url = 'http://localhost:3004/api/v1/documents'

  config.acapi.publish_amqp_events = true
  config.acapi.app_id = "enroll"
  config.acapi.remote_broker_uri = "amqp://#{ENV['RABBITMQ_USERNAME']}:#{ENV['RABBITMQ_PASSWORD']}@#{ENV['RABBITMQ_HOST']}:#{ENV['RABBITMQ_PORT']}"
  config.acapi.remote_request_exchange = "#{ENV['HBX_ID']}.#{ENV['ENV_NAME']}.e.fanout.requests"
  config.acapi.remote_event_queue = "#{ENV['HBX_ID']}.#{ENV['ENV_NAME']}.q.application.enroll.inbound_events"
  config.action_mailer.default_url_options = { :host => ENV['ENROLL_FQDN'].to_s }
  config.acapi.hbx_id = ENV['HBX_ID'].to_s
  config.acapi.environment_name = ENV['ENV_NAME'].to_s

  # Cartafact config
  config.cartafact_document_base_url = "http://#{ENV['CARTAFACT_HOST']}:3000/api/v1/documents"

  #Queue adapter
  config.active_job.queue_adapter = :resque

  HbxIdGenerator.slug!
  config.ga_tracking_id = ENV['GA_TRACKING_ID'] || "dummy"
  config.ga_tagmanager_id = ENV['GA_TAGMANAGER_ID'] || "dummy"

  Mongoid.logger.level = Logger::ERROR
  Mongo::Logger.logger.level = Logger::ERROR

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
