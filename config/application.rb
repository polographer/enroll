# frozen_string_literal: true

# Devise security won't work without this.
DEVISE_ORM = :mongoid

require_relative 'boot'
require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require "rails/test_unit/railtie"

# Configure fallbacks for mongoid errors:
require "i18n/backend/fallbacks"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require File.join(File.dirname(__FILE__), "json_log_format")

module Enroll
  class Application < Rails::Application
    # Custom exceptions
    # https://stackoverflow.com/a/19279062/5331859
    config.exceptions_app = ->(env) { ExceptionsController.action(:show).call(env) }
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += ["#{config.root}/lib", "#{config.root}/app/notices", "#{config}/app/jobs"]
    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = [:am, :en, :es, :ja]
    config.i18n.default_locale = :en

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true
    config.assets.enabled = true
    config.assets.paths << "#{Rails.root}/app/assets/info"
    I18n::Backend::Simple.include I18n::Backend::Fallbacks
    config.i18n.fallbacks = [I18n.default_locale, {'am' => 'en', 'es' => 'en', 'ja' => 'en'}]
    config.paths.add "app/api", glob: "**/*.rb"
    config.autoload_paths += Dir["#{Rails.root}/app/api/api/*/*"]

    #Thanks to Wojtek Kruszewski: https://gist.github.com/WojtekKruszewski
    config.log_tags = [    #'-anything',
      lambda { |req|
        SessionTaggedLogger.extract_session_id_from_request(req)
      }
    ]

    unless Rails.env.test?
      config.acapi.add_subscription("Events::ResidencyVerificationRequestsController")
      config.acapi.add_subscription("Events::SsaVerificationRequestsController")
      config.acapi.add_subscription("Events::VlpVerificationRequestsController")
      config.acapi.add_async_subscription("Subscribers::DateChange")
      config.acapi.add_async_subscription("Subscribers::NfpStatementHistory")
      config.acapi.add_async_subscription("Subscribers::SsaVerification")
      config.acapi.add_async_subscription("Subscribers::LawfulPresence")
      config.acapi.add_async_subscription("Subscribers::LocalResidency")
      config.acapi.add_async_subscription("Subscribers::FamilyApplicationCompleted")
      config.acapi.add_async_subscription("Subscribers::IamAccountCreation")
      config.acapi.add_async_subscription("Subscribers::NotificationSubscriber")
      config.acapi.add_async_subscription("Subscribers::DefaultGaChanged")
      config.acapi.add_async_subscription("Subscribers::ShopBinderEnrollmentsTransmissionAuthorized")
      config.acapi.add_async_subscription("Subscribers::ShopRenewalTransmissionAuthorized")
      config.acapi.add_async_subscription("Subscribers::ShopInitialEmployerQuietPeriodEnded")
      config.acapi.add_async_subscription("Subscribers::PolicyTerminationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeEnrollmentInvitationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeePassiveRenewalsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeInitialEnrollmentInvitationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeRenewalInvitationsSubscriber")
      config.acapi.add_async_subscription("FinancialAssistance::Subscribers::ApplicationEligibilityResponse")
      config.acapi.add_amqp_worker("BenefitSponsors::Subscribers::EmployerBenefitRenewalSubscriber")
      config.acapi.add_amqp_worker("Subscribers::ImportMcrApplication")
      config.acapi.add_amqp_worker("Subscribers::ImportMcrEnrollment")
      config.acapi.add_amqp_worker("Subscribers::RenewEnrollmentSubscriber")
      config.acapi.add_amqp_worker("BenefitSponsors::Subscribers::BenefitPackageRenewalGroupAssignmentSubscriber", ENV['AMQP_WORKERS_COUNT'] || 1)
      config.acapi.add_amqp_worker("BenefitSponsors::Subscribers::BenefitPackageEmployeeRenewerSubscriber", ENV['AMQP_WORKERS_COUNT'] || 1)
      config.acapi.add_amqp_worker("BenefitSponsors::Subscribers::BenefitPackageReinstateGroupAssignmentSubscriber")
      config.acapi.add_amqp_worker("BenefitSponsors::Subscribers::ReinstateEmployeeEnrollmentSubscriber")
      config.acapi.add_amqp_worker("TransportProfiles::Subscribers::TransportArtifactSubscriber")
      config.acapi.add_async_subscription("Notifier::NotificationSubscriber")
    end
  end
end
