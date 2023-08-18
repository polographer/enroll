# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Eligible
    # Operation to migrate benefit sponsor catalog
    class MigrateBenefitSponsorCatalog
      send(:include, Dry::Monads[:result, :do])

      # @param [Hash] opts Options to migrate benefit sponsor catalog
      # @option opts [<String>]   :sponsorship_id required
      # @return [Dry::Monad] result
      def call(params)
        benefit_sponsorship = yield find_sponsorship(values)
        applications = yield verify_migration_eligible(benefit_sponsorship)
        _errors = yield check_ref_plan_and_enrollments(applications)
        catalog = yield update_catalog(benefit_sponsorship, applications)

        Success(catalog)
      end

      private

      def find_sponsorship(values)
        subject = GlobalID::Locator.locate(values[:sponsorship_id])

        Success(subject)
      end

      def verify_migration_eligible(benefit_sponsorship)
        applications = applications_for(benefit_sponsorship)
        eligible_applications = []
        applications.each do |application|
          start_on = application.start_on
          next unless calendar_years.include?(start_on.year)

          eligibility =
            eligibility_for(
              "aca_shop_osse_eligibility_#{start_on.year}".to_sym,
              start_on
            )
          next unless eligibility
          next unless application.created_at > eligibility.created_at

          eligible_applications << application
        end
      end

      def check_ref_plan_and_enrollments(applications)
        errors = []

        logger.info "validating  #{benefit_sponsorship.legal_name}(#{benefit_sponsorship.fein})"

        applications.each do |application|
          if application.benefit_packages.any? { |benefit_package|
               benefit_package
                 .health_sponsored_benefit
                 &.product_package_kind
                 .to_s != "metal_level"
             }
            errors << "found non metal level product package for application #{application.start_on} #{application.aasm_state}"
          end

          if application.benefit_packages.any? { |benefit_package|
               benefit_package
                 .health_sponsored_benefit
                 &.reference_product
                 &.metal_level_kind
                 .to_s == "bronze"
             }
            errors << "found bronze reference plan for application #{application.start_on} #{application.aasm_state}"
          end

          if application.benefit_packages.any? { |benefit_package|
               families = benefit_package.enrolled_and_terminated_families
               families.any? do |family|
                 enrollment_for_package(family, benefit_package).any? do |en|
                   en.product&.metal_level_kind.to_s == "bronze"
                 end
               end
             }
            errors << "found employees enrolled in bronze plan for application #{application.start_on} #{application.aasm_state}"
          end

          if application.benefit_packages.any? { |benefit_package|
               families = benefit_package.enrolled_and_terminated_families
               families.all? do |family|
                 enrollment_for_package(family, benefit_package).none? do |en|
                   en.eligible_child_care_subsidy > 0
                 end
               end
             }
            errors << "found no employees with subsidy for application #{application.start_on} #{application.aasm_state}"
          end
        end

        return Success(errors) unless errors.present?
        logger.info "failed validation due to #{errors.inspect}"
        Failure(errors)
      end

      def enrollment_for_package(family, benefit_package)
        enrollments =
          family.hbx_enrollments.by_health.by_benefit_package(benefit_package)

        enrollments.enrolled_waived_terminated_and_expired.where(
          :aasm_state.nin => HbxEnrollment::WAIVED_STATUSES
        )
      end

      def update_catalog(benefit_sponsorship, applications)
        logger.info "updating catalog for #{benefit_sponsorship.legal_name}(#{benefit_sponsorship.fein})"
        applications.each do |application|
          logger.info "updating application catalog for #{application.start_on} #{application.aasm_state}"
          sponsor_catalog = application.benefit_sponsor_catalog
          sponsor_catalog.tap do |catalog|
            catalog.product_packages.delete_if do |package|
              package.product_kind == :health &&
                package.package_kind != :metal_level
            end

            catalog
              .product_packages
              .detect do |package|
                package.product_kind == :health &&
                  package.package_kind == :metal_level
              end
              .tap do |package|
                package.products.delete_if do |product|
                  product.health? && product.metal_level_kind == :bronze
                end
              end
          end

          sponsor_catalog.save
          sponsor_catalog.create_sponsor_eligibilities
          logger.info "updated application catalog for #{application.start_on} #{application.aasm_state}"
        end
      end

      def logger
        @logger =
          Logger.new(
            "#{Rails.root}/log/migrate_benefit_sponsor_catalogs_#{TimeKeeper.date_of_record.strftime("%Y_%m_%d")}.log"
          ) unless defined?(@logger)
        @logger
      end

      def applications_for(benefit_sponsorship)
        benefit_sponsorship.benefit_applications.approved_and_terminated
      end

      def calendar_years
        [Date.today.year - 1, Date.today.year]
      end
    end
  end
end