class GroupSelectionPrevaricationAdapter

  include ActiveModel::Model
  include Config::SiteModelConcern

  attr_accessor :optional_effective_on, :shop_under_current, :shop_under_future, :person, :family,
                :coverage_household, :previous_hbx_enrollment, :change_plan, :coverage_kind, :enrollment_kind, :shop_for_plans, :latest_enrollment

  def self.initialize_for_common_vars(params)
    person_id = params[:person_id]
    person = Person.find(person_id)
    family = person.primary_family
    coverage_household = family.active_household.immediate_family_coverage_household
    change_plan = params[:change_plan].present? ? params[:change_plan] : ''
    shop_under_current = params[:shop_under_current] == "true"
    shop_under_future = params[:shop_under_future] == "true"
    coverage_kind = params[:coverage_kind].present? ? params[:coverage_kind] : 'health'
    enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''
    shop_for_plans = params[:shop_for_plans].present? ? params[:shop_for_plans] : ''
    optional_effective_on = params[:effective_on_option_selected].present? ? Date.strptime(params[:effective_on_option_selected], '%m/%d/%Y') : nil
    record = self.new(
      person: person,
      family: family,
      coverage_household: coverage_household,
      change_plan: change_plan,
      coverage_kind: coverage_kind,
      enrollment_kind: enrollment_kind,
      shop_for_plans: shop_for_plans,
      optional_effective_on: optional_effective_on,
      shop_under_current: shop_under_current,
      shop_under_future: shop_under_future
    )
    if params[:hbx_enrollment_id].present?
      enrollment = ::HbxEnrollment.find(params[:hbx_enrollment_id])
      record.previous_hbx_enrollment = enrollment if enrollment.coverage_kind == coverage_kind
    end
    record.check_shopping_roles(params)
    record.latest_enrollment = family.active_household.hbx_enrollments.where(:aasm_state.nin => ['shopping']).order_by(:created_at.desc).first
    record
  end

  def check_shopping_roles(params)
    if params[:employee_role_id].present? && is_shop_or_fehb_market_enabled?
      emp_role_id = params.require(:employee_role_id)
      @employee_role = @person.employee_roles.detect { |emp_role| emp_role.id.to_s == emp_role_id.to_s }
    elsif params[:resident_role_id].present? && is_individual_market_enabled?
      @resident_role = @person.resident_role
    end
  end

  def can_ivl_shop?(params)
    return false unless is_individual_market_enabled?

    (select_market(params) == 'individual') || (@person.try(:has_active_employee_role?) && @person.try(:has_active_consumer_role?)) || @person.resident_role?
  end

  def possible_resident_person
    @person.resident_role? ? @person : nil
  end

  def if_changing_ivl?(params)
    can_ivl_shop?(params) && params[:hbx_enrollment_id].present?
  end

  def if_employee_role_unset_but_can_be_derived(e_role_value)
    return if e_role_value.present? || !is_shop_or_fehb_market_enabled?
    if @person.has_active_employee_role?
      @person.active_employee_roles.first
    end
  end

  def if_previous_enrollment_was_special_enrollment
    return nil unless @previous_hbx_enrollment.present?
    if @previous_hbx_enrollment.is_special_enrollment?
      @change_plan = 'change_by_qle'
      yield
    end
  end

  def if_family_has_active_shop_sep
    latest_shop_or_fehb_sep = @family.latest_shop_sep || @family.latest_fehb_sep
    return unless @previous_hbx_enrollment.present?
    return unless @previous_hbx_enrollment.is_shop?
    return unless latest_shop_or_fehb_sep.present?
    benefit_package = @previous_hbx_enrollment.sponsored_benefit_package
    return unless benefit_package.effective_period.cover?(latest_shop_or_fehb_sep.effective_on)
    @change_plan = 'change_by_qle'
    yield
  end

  def if_family_has_active_sep
    return nil if @previous_hbx_enrollment.blank?
    return unless @family.has_active_sep?(@previous_hbx_enrollment)
    @change_plan = 'change_by_qle'
    yield
  end

  def possible_employee_role
    return unless is_shop_or_fehb_market_enabled?
    if @employee_role.nil? && @person.has_active_employee_role?
      @person.active_employee_roles.first
    else
      @employee_role
    end
  end

  def if_employee_role
    return nil unless possible_employee_role.present? && is_shop_or_fehb_market_enabled?
    yield possible_employee_role
  end

  def if_resident_role
    return nil unless @resident_role.present? && is_individual_market_enabled?
    yield @resident_role
  end

  def if_consumer_role
    return nil if (@employee_role.present? || @resident_role.present?) && !is_individual_market_enabled?
    yield person.consumer_role
  end

  def keep_existing_plan?(params)
    params[:commit] == "Keep existing plan"
  end

  def benefit_group_assignment_by_plan_year(employee_role, benefit_group, change_plan)
    benefit_group.plan_year.is_renewing? ?
      employee_role.census_employee.renewal_benefit_group_assignment : (benefit_group.plan_year.aasm_state == "expired" && (change_plan == 'change_by_qle' or enrollment_kind == 'sep')) ? employee_role.census_employee.benefit_group_assignments.where(benefit_group_id: benefit_group.id).first : employee_role.census_employee.active_benefit_group_assignment
  end

  def set_mc_variables
    if @previous_hbx_enrollment.present? && @change_plan == "change_plan"
      m_kind = if @previous_hbx_enrollment.employer_profile.is_a?(BenefitSponsors::Organizations::FehbEmployerProfile) && is_fehb_market_enabled?
                 "fehb"
               elsif @previous_hbx_enrollment.is_shop? && is_shop_market_enabled?
                 'shop'
               elsif (%w[coverall individual].include? @previous_hbx_enrollment.kind) && is_individual_market_enabled?
                 @previous_hbx_enrollment.kind
               end
      yield m_kind, @previous_hbx_enrollment.coverage_kind
    end
  end

  def disable_market_kinds(params)
    if (@change_plan == 'change_by_qle' || @enrollment_kind == 'sep')
      d_market_kind = (select_market(params) == "shop" || select_market(params) == "fehb") && is_shop_or_fehb_market_enabled? ? "individual" : "shop"
    else
      d_market_kind = 'individual' if (@person.consumer_role.present? || @person.resident_role.present?) && !is_under_ivl_open_enrollment?

      d_market_kind = 'shop' if !@employee_role&.is_eligible_to_enroll_without_qle? && !is_shop_or_fehb_market_enabled?
    end

    yield d_market_kind
  end

  def is_under_ivl_open_enrollment?
    HbxProfile.current_hbx.present? ? HbxProfile.current_hbx.under_open_enrollment? : nil
  end

  def ivl_benefit
    correct_effective_on = calculate_ivl_effective_on
    if @change_plan.present? && @previous_hbx_enrollment.present? && @previous_hbx_enrollment.is_ivl_by_kind?
      HbxProfile.current_hbx.benefit_sponsorship.benefit_coverage_periods.select{|bcp| bcp.contains?(correct_effective_on)}.first.benefit_packages.select{|bp|  bp.effective_year == correct_effective_on.year && bp.benefit_categories.include?(@previous_hbx_enrollment.coverage_kind)}.first
    else
      HbxProfile.current_hbx.benefit_sponsorship.benefit_coverage_periods.select{|bcp| bcp.contains?(correct_effective_on)}.first.benefit_packages.select{|bp|  bp[:title] == "individual_health_benefits_#{correct_effective_on.year}"}.first
    end
  end

  def calculate_ivl_effective_on
    calculate_effective_on(market_kind: 'individual', employee_role: nil, benefit_group: nil)
  end

  def calculate_coverall_effective_on
    calculate_effective_on(market_kind: 'coverall', employee_role: nil, benefit_group: nil)
  end

  def calculate_new_effective_on(params)
    benefit_group = select_benefit_group(params)
    calculate_effective_on(market_kind: select_market(params), employee_role: possible_employee_role, benefit_group: benefit_group)
  end

  def calculate_effective_on(market_kind:, employee_role:, benefit_group:)
    HbxEnrollment.calculate_effective_on_from(
      market_kind: market_kind,
      qle: (@change_plan == 'change_by_qle' or @enrollment_kind == 'sep'),
      family: @family,
      employee_role: employee_role,
      benefit_group: benefit_group,
      benefit_sponsorship: HbxProfile.current_hbx.try(:benefit_sponsorship))
  end

  def if_qle_with_date_option_selected(params)
    if params[:effective_on_option_selected].present?
      yield Date.strptime(params[:effective_on_option_selected], '%m/%d/%Y')
    end
  end

  def if_change_plan_selected(params)
    if @change_plan == 'change_plan' && @previous_hbx_enrollment.present?
      yield @previous_hbx_enrollment.effective_on
    end
  end

  def if_should_generate_coverage_family_members_for_cobra(params)
    return [] unless is_shop_or_fehb_market_enabled?

    if (select_market(params) == "shop" || select_market(params) == "fehb") && !(@change_plan == 'change_by_qle' || @enrollment_kind == 'sep') && possible_employee_role.present? && possible_employee_role.is_cobra_status?
      hbx_enrollment = @family.active_household.hbx_enrollments.shop_market.enrolled_and_renewing.effective_desc.detect { |hbx| hbx.may_terminate_coverage? }
      if hbx_enrollment.present?
        yield(hbx_enrollment.hbx_enrollment_members.map(&:family_member))
      end
    end
  end

  def if_hbx_enrollment_unset_and_sep_or_qle_change_and_can_derive_previous_shop_enrollment(params, enrollment, new_effective_date)
    if (select_market(params) == 'shop' || select_market(params) == 'fehb') && (@change_plan == 'change_by_qle') && enrollment.blank?

      prev_enrollment = find_previous_enrollment_for(params, new_effective_date)
      if prev_enrollment
        yield prev_enrollment
      else
        yield nil, nil
      end
    end
  end

  def can_waive?(hbx_enrollment, params)
    return false unless is_shop_market_enabled? || is_fehb_market_enabled?

    if hbx_enrollment.present?
      hbx_enrollment.is_shop?
    else
      select_market(params) == 'shop' || select_market(params) == 'fehb'
    end
  end

  def find_previous_enrollment_for(params, new_effective_date)
    @family.households.flat_map(&:hbx_enrollments).detect do |other_enrollment|
      (other_enrollment.employee_role_id == possible_employee_role.id) &&
        other_enrollment.active_during?(new_effective_date) &&
        (other_enrollment.coverage_kind == @coverage_kind)
    end
  end

  def is_qle?
    (@change_plan == 'change_by_qle' or @enrollment_kind == 'sep')
  end

  def select_benefit_group(params)
    return unless (select_market(params) == 'shop' || select_market(params) == 'fehb') && is_shop_or_fehb_market_enabled?

    if possible_employee_role.present?
      assigned_benefit_package = possible_employee_role.benefit_package(qle: is_qle?, shop_under_current: shop_under_current, shop_under_future: shop_under_future)
    end

    if @change_plan.present? && @previous_hbx_enrollment.present?
      possible_benefit_package = @previous_hbx_enrollment.sponsored_benefit_package
      return possible_benefit_package if assigned_benefit_package && assigned_benefit_package.start_on != possible_benefit_package.start_on
    end

    assigned_benefit_package
  end

  def renewal_enrollment(enrollments, employee_role)
    enrollments.where({
      :"benefit_group_id" => employee_role.census_employee.renewal_published_benefit_group.try(:id),
      :"aasm_state".in => HbxEnrollment::RENEWAL_STATUSES
    }).first
  end

  def active_enrollment(enrollments, employee_role)
    enrollments.where({
      :"benefit_group_id" => employee_role.census_employee.active_benefit_group.try(:id),
      :"aasm_state".in => HbxEnrollment::ENROLLED_STATUSES
    }).first
  end

  def select_market(params)
    return params[:market_kind] if params[:market_kind].present?
    if params[:qle_id].present? && (!person.has_active_resident_role?)
      qle = QualifyingLifeEventKind.find(params[:qle_id])
      return qle.market_kind
    end
    if is_fehb?(person) && is_fehb_market_enabled?
      'fehb'
    elsif person.has_active_employee_role? && is_shop_market_enabled?
      'shop'
    elsif person.is_consumer_role_active? && is_individual_market_enabled?
      'individual'
    elsif person.is_resident_role_active? && is_individual_market_enabled?
      'coverall'
    else
      nil
    end
  end

  def create_action_market_kind(params)
    if params[:market_kind].present?
      return "fehb" if params[:market_kind] == "shop" && is_fehb?(person) && is_fehb_market_enabled?
      params[:market_kind]
    elsif is_shop_market_enabled?
      "shop"
    elsif is_individual_market_enabled?
      "individual"
    end
  end

  # SHOP enrollment creation adapters
  def build_shop_change_enrollment(
    controller_employee_role,
    controller_change_plan,
    family_member_ids
  )
    return unless is_shop_or_fehb_market_enabled?

    e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(coverage_household, controller_employee_role, coverage_kind)
    e_builder.build_change_enrollment(previous_enrollment: previous_hbx_enrollment, is_qle: is_qle?, optional_effective_on: optional_effective_on, family_member_ids: family_member_ids)
  end

  def build_new_shop_enrollment(controller_employee_role, family_member_ids)
    return unless is_shop_or_fehb_market_enabled?

    build_new_shop_enrollment_for_family_members(controller_employee_role, family_member_ids)
  end

  def build_new_shop_waiver_enrollment(controller_employee_role, params)
    return unless is_shop_or_fehb_market_enabled?

    e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(coverage_household, controller_employee_role, coverage_kind)
    e_builder.build_new_waiver_enrollment(is_qle: is_qle?, shop_under_current: shop_under_current, shop_under_future: shop_under_future, optional_effective_on: optional_effective_on, waiver_reason: get_waiver_reason(params))
  end

  def build_change_shop_waiver_enrollment(
    controller_employee_role,
    controller_change_plan,
    params
  )
    return unless is_shop_or_fehb_market_enabled?

    e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(coverage_household, controller_employee_role, coverage_kind)
    e_builder.build_change_waiver_enrollment(previous_enrollment: previous_hbx_enrollment, is_qle: is_qle?, optional_effective_on: optional_effective_on, waiver_reason: get_waiver_reason(params))
  end

  def is_waiving?(params)
    return false unless is_shop_or_fehb_market_enabled?
    !params[:is_waiving].blank?
  end

  def get_waiver_reason(params)
    params[:waiver_reason]
  end

  def can_shop_shop?(person)
    person.present? && person.has_employer_benefits? && is_shop_or_fehb_market_enabled?
  end

  def is_fehb?(person)
    person.present? && person.active_employee_roles.present? && person.active_employee_roles.any?{|r| r.employer_profile.is_a?(BenefitSponsors::Organizations::FehbEmployerProfile)}
  end

  def can_shop_individual?(person)
    return false unless is_individual_market_enabled?

    person.try(:has_active_consumer_role?)
  end

  def can_shop_resident?(person)
    return false unless is_individual_market_enabled?

    person.try(:has_active_resident_role?)
  end

  def can_shop_both_markets?(person)
    can_shop_individual?(person) && can_shop_shop?(person)
  end

  def no_employer_benefits_error_message(hbx_enrollment)
    if hbx_enrollment.sponsored_benefit_package.benefit_application.terminated?
      "Your employer is no longer offering health insurance through #{EnrollRegistry[:enroll_app].setting(:short_name).item}. Please contact your employer."
    elsif hbx_enrollment.sponsored_benefit_package.benefit_application.termination_pending?
      "Your employer is no longer offering health insurance through #{EnrollRegistry[:enroll_app].setting(:short_name).item}."\
      " Please contact your employer or call our Customer Care Center at #{EnrollRegistry[:enroll_app].setting(:health_benefit_exchange_authority_phone_number).item}."
    else
      "Unable to find employer-sponsored benefits for enrollment year #{hbx_enrollment.effective_on.year}"
    end
  end

  def is_eligible_for_dental?(employee_role, change_plan, enrollment, effective_date)
    return unless employee_role.present?

    renewal_benefit_package = employee_role.census_employee.renewal_published_benefit_package
    active_benefit_package  = employee_role.census_employee.active_benefit_package(effective_date)

    if change_plan == "change_by_qle"
      benefit_package = fetch_benefit_package_for_sep(employee_role)
      benefit_package.present? && benefit_package.is_offering_dental?
    elsif change_plan == 'change_plan' && enrollment.present? && enrollment.is_shop?
      enrollment.sponsored_benefit_package.is_offering_dental?
    elsif employee_role.can_enroll_as_new_hire?
      active_benefit_package.present? && active_benefit_package.is_offering_dental?
    else
      current_benefit_package = (renewal_benefit_package || active_benefit_package)
      current_benefit_package.present? && current_benefit_package.is_offering_dental?
    end
  end

  def is_offering_dental(employee)
    employee.benefit_package&.is_offering_dental?
  end

  def fetch_benefit_package_for_sep(employee_role)
    return unless employee_role.present?

    family = employee_role.person.primary_family
    employee_role.census_employee.benefit_package_for_date(family.earliest_effective_sep.effective_on) ||
      employee_role.benefit_package(qle: true) ||
      employee_role.census_employee.possible_benefit_package
  end

  # def is_dental_offered?(employee_role)
  #   census_employee = employee_role.census_employee
  #   current_benefit_package = census_employee.renewal_published_benefit_package || census_employee.active_benefit_package
  #   current_benefit_package.present? && current_benefit_package.is_offering_dental?
  # end

  def shop_health_and_dental_attributes(family_member, employee_role, coverage_start, qle)
    benefit_group = get_benefit_group(@benefit_group, employee_role, qle)

    # Here we need to use the complex method to determine if this member is eligible to enroll
    [
      benefit_group && eligibility_checker(benefit_group, :health).can_cover?(family_member, coverage_start),
      benefit_group && eligibility_checker(benefit_group, :dental).can_cover?(family_member, coverage_start)
    ]
  end

  def eligibility_checker(benefit_group, coverage_kind)
    shop_benefit_eligibilty_checker_for(benefit_group, coverage_kind)
  end

  def class_for_ineligible_row(family_member, is_ivl_coverage, coverage_start, qle)
    class_names = @person.active_employee_roles.inject([]) do |class_names, employee_role|
      is_health_coverage, is_dental_coverage = shop_health_and_dental_attributes(family_member, employee_role, coverage_start, qle)

      if !is_health_coverage && !is_health_coverage.nil?
        class_names << "ineligible_health_row_#{employee_role.id}"
      end

      if !is_dental_coverage && !is_dental_coverage.nil?
        class_names << "ineligible_dental_row_#{employee_role.id}"
      end
      class_names
    end

    class_names << "ineligible_ivl_row" if (!is_ivl_coverage.nil? && !is_ivl_coverage)
    class_names << "is_primary" if family_member.is_primary_applicant?

    class_names.to_sentence.gsub("and", '').gsub(",", "")
  end

  def get_benefit_group(benefit_group, employee_role, qle)
    if benefit_group.present? && (employee_role.employer_profile == benefit_group.sponsor_profile)
      benefit_group
    else
      select_benefit_group_from_qle_and_employee_role(qle, employee_role)
    end
  end

  def select_benefit_group_from_qle_and_employee_role(qle, employee_role)
    return unless employee_role.present?

    employee_role.benefit_package(qle: qle)
  end

  # Assignment will never be nil unless you're setting incorrect sponsored_benefit_package on enrollment
  def assign_enrollment_to_benefit_package_assignment(employee_role, enrollment)
    assignment = employee_role.census_employee.benefit_group_assignment_by_package(enrollment.sponsored_benefit_package_id, enrollment.effective_on)
    assignment.update(hbx_enrollment_id: enrollment.id)
    enrollment.update(benefit_group_assignment_id: assignment.id)
  end

  protected

  def build_new_shop_enrollment_for_family_members(
    controller_employee_role,
    family_member_ids
  )

    e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(coverage_household, controller_employee_role, coverage_kind)
    e_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: is_qle?, shop_under_current: shop_under_current, shop_under_future: shop_under_future,  optional_effective_on: optional_effective_on)
  end

  def shop_health_and_dental_relationship_benefits(employee_role, benefit_group, effective_date)
    health_offered_relationship_benefits = health_relationship_benefits(benefit_group)
    dental_offered_relationship_benefits = nil

    dental_offered_relationship_benefits = dental_relationship_benefits(benefit_group) if is_eligible_for_dental?(employee_role, @change_plan, @hbx_enrollment, effective_date)

    return health_offered_relationship_benefits, dental_offered_relationship_benefits
  end

  def health_relationship_benefits(benefit_group)
    return unless benefit_group.present?

    benefit_group.sole_source? ? composite_benefits(benefit_group) : traditional_benefits(benefit_group)
  end

  def composite_benefits(benefit_group)
    benefit_group.composite_tier_contributions.select(&:offered).map(&:composite_rating_tier)
  end

  def traditional_benefits(benefit_group)
    benefit_group.relationship_benefits.select(&:offered).map(&:relationship)
  end

  def shop_eligibility_checkers
    @shop_eligibility_checkers ||= Hash.new
  end

  def shop_benefit_eligibilty_checker_for(benefit_package, coverage_kind)
    shop_eligibility_checkers[coverage_kind] ||= GroupSelectionEligibilityChecker.new(benefit_package, coverage_kind)
  end
end
