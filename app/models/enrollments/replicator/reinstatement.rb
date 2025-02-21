# frozen_string_literal: true

module Enrollments
  module Replicator
    class Reinstatement

      attr_accessor :base_enrollment, :new_effective_date, :new_aptc, :year, :duplicate_hbx, :reinstate_enrollment, :eligible_dependents

      def initialize(enrollment, effective_date, new_aptc = nil, eligible_dependents = nil)
        @base_enrollment = enrollment
        @new_effective_date = effective_date
        @new_aptc = new_aptc
        @year = effective_date.year
        # TODO: dupliate_hbx was in the inherited code but was undefined. Need to know
        # what it is supposed to be
        @duplicate_hbx = enrollment.dup
        @eligible_dependents = eligible_dependents
      end

      def benefit_application
        base_enrollment.sponsored_benefit_package.benefit_application
      end

      def census_employee
        base_enrollment.benefit_group_assignment.census_employee
      end

      def reinstate_under_renewal_py?
        new_effective_date > benefit_application.end_on
      end

      def renewal_benefit_application
        benefit_application.benefit_sponsorship.benefit_applications.renewing.published_benefit_applications_by_date(new_effective_date).first
      end

      def renewal_benefit_group_assignment
        assignment = census_employee.renewal_benefit_group_assignment
        if assignment.blank? && census_employee.active_benefit_group_assignment(new_effective_date).blank?
          census_employee.save
        elsif renewal_benefit_application == census_employee.published_benefit_group_assignment.benefit_application
          assignment = census_employee.published_benefit_group_assignment
        end
        assignment
      end

      def reinstatement_plan
        if reinstate_under_renewal_py?
          base_enrollment.product.renewal_product
        else
          base_enrollment.product
        end
      end

      def reinstatement_benefit_group_assignment
        if reinstate_under_renewal_py?
          renewal_benefit_group_assignment.id
        else
          base_enrollment.benefit_group_assignment_id
        end
      end

      def reinstatement_sponsored_benefit_package
        if reinstate_under_renewal_py?
          renewal_benefit_group_assignment.benefit_group
        else
          base_enrollment.sponsored_benefit_package
        end
      end

      def reinstatement_sponsored_benefit
        if base_enrollment.coverage_kind == 'health'
          reinstatement_sponsored_benefit_package.health_sponsored_benefit
        else
          reinstatement_sponsored_benefit_package.dental_sponsored_benefit
        end
      end

      def reinstate_rating_area
        if reinstate_under_renewal_py?
          renewal_benefit_group_assignment.benefit_application.recorded_rating_area_id
        else
          base_enrollment.rating_area_id
        end
      end

      def renewal_plan_offered_by_er?(renewal_plan)
        reinstatement_sponsored_benefit.products(new_effective_date).map(&:_id).include?(renewal_plan.id)
      end

      def can_be_reinstated?
        raise "Unable to reinstate enrollment: your Employer Sponsored Benefits no longer offerring the plan (#{reinstatement_plan.name})." if reinstate_under_renewal_py? && !renewal_plan_offered_by_er?(reinstatement_plan)
        true
      end

      def build
        reinstated_enrollment = HbxEnrollment.new
        @reinstate_enrollment = reinstated_enrollment
        assign_all_attributes(reinstated_enrollment)

        reinstated_enrollment.hbx_enrollment_members = clone_hbx_enrollment_members
        unless base_enrollment.coverage_expired?
          if base_enrollment.may_terminate_coverage? && (reinstate_enrollment.effective_on > base_enrollment.effective_on)
            unless base_enrollment.ineligible_for_termination?(new_effective_date)
              base_enrollment.terminate_coverage!
              base_enrollment.update_attributes!(terminated_on: new_effective_date - 1.day)
            end
          elsif base_enrollment.enrollment_superseded_and_eligible_for_cancellation?(new_effective_date)
            base_enrollment.cancel_coverage_for_superseded_term!
          elsif base_enrollment.may_cancel_coverage?
            base_enrollment.cancel_coverage!
          end
        end

        @reinstate_enrollment = reinstated_enrollment
        reinstated_enrollment
      end

      def assign_all_attributes(reinstated_enrollment)
        assign_attributes_to_reinstate_enrollment(reinstated_enrollment, common_params)
        if base_enrollment.is_shop?
          assign_attributes_to_reinstate_enrollment(reinstated_enrollment, form_shop_params) if can_be_reinstated?
        elsif base_enrollment.is_ivl_by_kind?
          assign_attributes_to_reinstate_enrollment(reinstated_enrollment, form_ivl_params)

          if new_aptc.blank?
            reinstated_enrollment.elected_aptc_pct = base_enrollment.elected_aptc_pct
            reinstated_enrollment.applied_aptc_amount = base_enrollment.applied_aptc_amount
            reinstated_enrollment.eligible_child_care_subsidy = base_enrollment.eligible_child_care_subsidy
          end
        end
      end

      def assign_attributes_to_reinstate_enrollment(enrollment, options = {})
        enrollment.assign_attributes(options)
      end

      def form_shop_params
        {
          employee_role_id: base_enrollment.employee_role_id,
          benefit_group_assignment_id: reinstatement_benefit_group_assignment,
          sponsored_benefit_package_id: reinstatement_sponsored_benefit_package.id,
          sponsored_benefit_id: reinstatement_sponsored_benefit.id,
          benefit_sponsorship_id: base_enrollment.benefit_sponsorship_id,
          product_id: reinstatement_plan.id,
          rating_area_id: reinstate_rating_area,
          issuer_profile_id: reinstatement_plan.issuer_profile_id
        }
      end

      def form_ivl_params
        # TODO: Query is too long
        # TODO: undefined local variable or method `year' for #<Enrollments::Replicator::Reinstatement:0x00007fca4bcb2970>
        new_product_id = base_enrollment.is_ivl_by_kind? ? product_id_csr_variant(base_enrollment) : base_enrollment.product_id
        {
          product_id: new_product_id,
          consumer_role_id: base_enrollment.consumer_role_id,
          rating_area_id: ::BenefitMarkets::Locations::RatingArea.rating_area_for(base_enrollment.consumer_role.rating_address, during: new_effective_date)&.id
        }
      end

      def all_american_indian_members(shopping_family_members_ids)
        shopping_family_members = base_enrollment.family.family_members.where(:id.in => shopping_family_members_ids)
        shopping_family_members.all?{|fm| fm.person.indian_tribe_member }
      end

      def extract_csr_kind
        shopping_family_members_ids = base_enrollment.hbx_enrollment_members.map(&:applicant_id)

        if EnrollRegistry.feature_enabled?(:temporary_configuration_enable_multi_tax_household_feature)
          result = ::Operations::PremiumCredits::FindCsrValue.new.call({ family: @base_enrollment.family,
                                                                         year: @year,
                                                                         family_member_ids: shopping_family_members_ids })

          result.value! if result.success?
        elsif EnrollRegistry.feature_enabled?(:native_american_csr) && all_american_indian_members(shopping_family_members_ids)
          'csr_limited'
        else
          tax_household = base_enrollment.family.active_household.latest_active_thh_with_year(@year)
          tax_household&.eligibile_csr_kind(base_enrollment.hbx_enrollment_members.map(&:applicant_id))
        end
      end

      def product_id_csr_variant(base_enrollment)
        eligible_csr = extract_csr_kind
        return base_enrollment.product_id if eligible_csr.blank?

        csr_variant = EligibilityDetermination::CSR_KIND_TO_PLAN_VARIANT_MAP[eligible_csr]
        products = ::BenefitMarkets::Products::HealthProducts::HealthProduct.by_year(@year).where({:hios_id => "#{base_enrollment.product.hios_base_id}-#{csr_variant}"})
        products.count >= 1 ? products.last.id : base_enrollment.product_id
      end

      def common_params
        {
          family: base_enrollment.family,
          household: base_enrollment.family.active_household,
          effective_on: new_effective_date,
          coverage_kind: base_enrollment.coverage_kind,
          enrollment_kind: base_enrollment.enrollment_kind,
          kind: base_enrollment.kind,
          special_enrollment_period_id: base_enrollment.special_enrollment_period_id,
          predecessor_enrollment_id: base_enrollment.id,
          hbx_enrollment_members: clone_hbx_enrollment_members
        }
      end

      def member_coverage_start_date(hbx_enrollment_member)
        if base_enrollment.is_shop? && reinstate_under_renewal_py?
          new_effective_date
        else
          hbx_enrollment_member.coverage_start_on || base_enrollment.effective_on || new_effective_date
        end
      end

      def clone_hbx_enrollment_members
        enr_members = if @eligible_dependents.present?
                        @eligible_dependents
                      else
                        base_enrollment.hbx_enrollment_members
                      end
        latest_enrollment = base_enrollment.family.active_household.hbx_enrollments.where(:aasm_state.nin => ['shopping']).order_by(:created_at.desc).first
        enr_members.inject([]) do |members, hbx_enrollment_member|
          member = latest_enrollment.hbx_enrollment_members.where(applicant_id: hbx_enrollment_member.applicant_id).first
          tobacco_use = member&.tobacco_use || 'N'
          members << HbxEnrollmentMember.new({
                                               applicant_id: hbx_enrollment_member.applicant_id,
                                               eligibility_date: new_effective_date,
                                               coverage_start_on: member_coverage_start_date(hbx_enrollment_member),
                                               is_subscriber: hbx_enrollment_member.is_subscriber,
                                               tobacco_use: tobacco_use
                                             })
        end
      end
    end
  end
end
