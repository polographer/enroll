# frozen_string_literal: true

RSpec.describe Operations::Families::AddFinancialAssistanceEligibilityDetermination, dbclean: :after_each do

  let!(:product) {FactoryBot.create(:benefit_markets_products_health_products_health_product, :ivl_product)}
  let!(:hbx_profile) {FactoryBot.create(:hbx_profile, :open_enrollment_coverage_period)}
  let!(:person) do
    FactoryBot.create(:person,
                      :with_consumer_role,
                      :with_active_consumer_role,
                      hbx_id: 'ff4489850cf44b30abd9523e3c515587',
                      last_name: 'Test',
                      first_name: 'Domtest34',
                      ssn: '243108282',
                      dob: Date.new(1984, 3, 8))
  end
  let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
  let(:application) do
    FactoryBot.create(:financial_assistance_application, params)
  end
  let(:params) do
    {:family_id => BSON::ObjectId(family.id),
     :assistance_year => 2020,
     :benchmark_product_id => BSON::ObjectId('5f6020f26e81d9c148d3db34'),
     :integrated_case_id => '2000',
     :applicants =>
         [{"_id" => BSON::ObjectId('5f5eaff32e1423c05646b14a'),
           "is_tobacco_user" => "unknown",
           "assisted_income_validation" => "pending",
           "assisted_mec_validation" => "pending",
           "aasm_state" => "verification_pending",
           "is_active" => true,
           "has_fixed_address" => true,
           "tax_filer_kind" => "tax_filer",
           "magi_medicaid_monthly_household_income" => {"cents" => 833_325.0, "currency_iso" => "USD"},
           "magi_medicaid_monthly_income_limit" => {"cents" => 228_617.0, "currency_iso" => "USD"},
           "magi_as_percentage_of_fpl" => 783.0,
           "age_left_foster_care" => nil,
           "children_expected_count" => nil,
           "workflow" => {"current_step" => 1},
           "name_pfx" => nil,
           "first_name" => "test",
           "middle_name" => nil,
           "last_name" => "final",
           "name_sfx" => nil,
           "encrypted_ssn" => "BNBMRqni1M95MDBg/kIb4g==\n",
           "gender" => "male",
           "dob" => "1988-09-01 00:00:00 UTC",
           "is_primary_applicant" => true,
           "family_member_id" => BSON::ObjectId(family.family_members[0].id),
           "person_hbx_id" => "ff4489850cf44b30abd9523e3c515587",
           "is_incarcerated" => false,
           "ethnicity" => ["", "", "", "", "", "", ""],
           "tribal_id" => nil,
           "no_ssn" => "0",
           "citizen_status" => "us_citizen",
           "is_consumer_role" => true,
           "same_with_primary" => false,
           "is_applying_coverage" => true,
           "no_dc_address" => false,
           "is_homeless" => false,
           "is_consent_applicant" => false,
           "is_living_in_state" => false,
           "is_temporarily_out_of_state" => false,
           "is_ia_eligible" => true,
           "is_medicaid_chip_eligible" => false,
           "is_non_magi_medicaid_eligible" => false,
           "is_totally_ineligible" => false,
           "is_without_assistance" => false,
           "has_income_verification_response" => false,
           "has_mec_verification_response" => false,
           "is_magi_medicaid" => false,
           "is_medicare_eligible" => false,
           "is_self_attested_disabled" => false,
           "is_self_attested_long_term_care" => false,
           "is_veteran" => false,
           "is_refugee" => false,
           "is_trafficking_victim" => false,
           "is_subject_to_five_year_bar" => false,
           "is_five_year_bar_met" => false,
           "is_forty_quarters" => false,
           "addresses" =>
               [{"_id" => BSON::ObjectId('5f5eaff22e1423c05646b148'),
                 "address_1" => "dc",
                 "address_2" => "",
                 "address_3" => "",
                 "county" => "",
                 "country_name" => "",
                 "kind" => "home",
                 "city" => "dc",
                 "state" => "DC",
                 "zip" => "22302"}],
           "is_required_to_file_taxes" => true,
           "is_claimed_as_tax_dependent" => false,
           "has_job_income" => false,
           "has_self_employment_income" => false,
           "has_other_income" => true,
           "has_deductions" => false,
           "has_enrolled_health_coverage" => false,
           "has_eligible_health_coverage" => false,
           "is_pregnant" => false,
           "is_post_partum_period" => false,
           "foster_care_us_state" => "",
           "student_kind" => "",
           "student_status_end_on" => "",
           "student_school_kind" => "",
           "is_self_attested_blind" => false,
           "has_daily_living_help" => false,
           "need_help_paying_bills" => false,
           "is_physically_disabled" => false,
           "is_veteran_or_active_military" => false,
           "is_vets_spouse_or_child" => false,
           "eligibility_determination_id" => BSON::ObjectId('5f5eb0542e1423c05646b19b'),
           "medicaid_household_size" => 1,
           "magi_medicaid_category" => "false",
           "member_determinations" => member_determinations}],
     :eligibility_determinations =>
         [{"_id" => BSON::ObjectId('5f5eb0542e1423c05646b19b'),
           "max_aptc" => {"cents" => 5826.0, "currency_iso" => "USD"},
           "yearly_expected_contribution" => {"cents" => 167_220.00, "currency_iso" => "USD"},
           "csr_percent_as_integer" => 94,
           "aptc_csr_annual_household_income" => {"cents" => 3_342_466.0, "currency_iso" => "USD"},
           "aptc_annual_income_limit" => {"cents" => 4_752_000.0, "currency_iso" => "USD"},
           "csr_annual_income_limit" => {"cents" => 2_970_000.0, "currency_iso" => "USD"},
           "hbx_assigned_id" => 10_002,
           "effective_starting_on" => "2020-09-09 00:00:00 UTC",
           "is_eligibility_determined" => true,
           "determined_at" => "2020-09-09 00:00:00 UTC",
           "source" => "Faa"}]}
  end
  let(:member_determinations) do
    [{
      'kind' => 'Medicaid/CHIP Determination',
      'criteria_met' => true,
      'determination_reasons' => [:mitc_override_not_lawfully_present_pregnant],
      "eligibility_overrides" => [
        {
          "override_rule" => "not_lawfully_present_pregnant",
          "override_applied" => true
        },
        {
          "override_rule" => "not_lawfully_present_chip_eligible",
          "override_applied" => false
        },
        {
          "override_rule" => "not_lawfully_present_under_twenty_one",
          "override_applied" => false
        }
    ]
    }]
  end

  it 'should be a container-ready operation' do
    expect(subject.respond_to?(:call)).to be_truthy
  end

  context 'success' do
    before do
      bcp = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      bcp.update_attributes!(slcsp_id: product.id)
      @result = subject.call(application)
      family.reload
      @thhs = family.active_household.tax_households
    end

    it 'should return success' do
      expect(@result).to be_a Dry::Monads::Result::Success
    end

    it 'should create Tax Household object' do
      expect(@thhs.count).to eq(1)
    end

    it 'should create Tax Household Member object' do
      expect(@thhs.first.tax_household_members.first.applicant_id).to eq(family.primary_applicant.id)
    end

    it 'should create Member Determination object' do
      member_determination = family.active_household&.latest_active_tax_household&.tax_household_members&.first&.member_determinations&.first
      applicant = params[:applicants].first
      expect(member_determination.created_at.present?).to be_truthy
      expect(member_determination.updated_at.present?).to be_truthy
      expect(member_determination.kind).to eq(applicant['member_determinations'].first['kind'])
      expect(member_determination.criteria_met).to eq(applicant['member_determinations'].first['criteria_met'])
      expect(member_determination.determination_reasons).to eq(applicant['member_determinations'].first['determination_reasons'])
    end

    it 'should create Eligibility Override objects' do
      eligibility_overrides = family.active_household.latest_active_tax_household.tax_household_members.first.member_determinations.first.eligibility_overrides
      eligibility_overrides.each do |override|
        expect(override.created_at.present?).to be_truthy
        expect(override.updated_at.present?).to be_truthy
        expect(override.override_rule.present?).to be_truthy
        expect(override.override_applied.is_a?(Mongoid::Boolean)).to be_truthy
      end
    end

    it 'should update yearly_expected_contribution value' do
      expect(@thhs.first.yearly_expected_contribution.to_f).to eq(1_672.20)
    end

    it 'should create Eligibility Determination object' do
      expect(@thhs.first.latest_eligibility_determination.max_aptc.to_f).to eq(58.26)
    end

    it 'should update csr on thh member' do
      expect(@thhs.first.tax_household_members.first.csr_eligibility_kind).to eq("csr_0")
    end
  end

  context 'creation of tax households for family' do
    context 'applicant ineligible' do
      context 'non applicant members' do
        before do
          applicant = params[:applicants].first
          applicant.merge!({"is_ia_eligible" => false,
                            "is_medicaid_chip_eligible" => false,
                            "is_totally_ineligible" => false,
                            "is_magi_medicaid" => false,
                            "is_non_magi_medicaid_eligible" => false,
                            "is_without_assistance" => false})
          @result = subject.call(application)
        end

        it 'should not create a tax household for non applicant members' do
          expect(family.active_household.tax_households.count).to eq(0)
        end
      end
    end
  end

  context 'csr_percent_as_integer' do
    before do
      bcp = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      bcp.update_attributes!(slcsp_id: product.id)
      params[:applicants].first.merge!(appli_addnl_params)
      @result = subject.call(application)
      family.reload
      @thhm = family.active_household.tax_households.first.tax_household_members.first
    end

    context "{ 73 => 'csr_73' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => 73,
          "csr_eligibility_kind" => 'csr_73' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_73')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(73)
      end
    end

    context "{ 87 => 'csr_87' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => 87,
          "csr_eligibility_kind" => 'csr_87' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_87')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(87)
      end
    end

    context "{ 94 => 'csr_94' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => 94,
          "csr_eligibility_kind" => 'csr_94' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_94')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(94)
      end
    end

    context "{ 100 => 'csr_100' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => 100,
          "csr_eligibility_kind" => 'csr_100' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_100')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(100)
      end
    end

    context "{ 0 => 'csr_0' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => 0,
          "csr_eligibility_kind" => 'csr_0' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_0')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(0)
      end
    end

    context "{ -1 => 'csr_limited' }" do
      let(:appli_addnl_params) do
        { "is_ia_eligible" => true,
          "csr_percent_as_integer" => -1,
          "csr_eligibility_kind" => 'csr_limited' }
      end

      it 'should return csr_eligibility_kind value correctly' do
        expect(@thhm.csr_eligibility_kind).to eq('csr_limited')
      end

      it 'should return csr_percent_as_integer value correctly' do
        expect(@thhm.csr_percent_as_integer).to eq(-1)
      end
    end
  end

  context 'failure' do
    before do
      bcp = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      bcp.update_attributes!(slcsp_id: product.id)
      params.except!(:family_id)
      @result = subject.call(application)
      family.reload
      @thhs = family.active_household.tax_households
    end

    it 'should return failure' do
      expect(@result).to be_a Dry::Monads::Result::Failure
    end

    it 'should not create Tax Household object' do
      expect(@thhs.count).to eq(0)
    end
  end

  describe '#call' do
    before do
      bcp = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      bcp.update_attributes!(slcsp_id: product.id)
      eligibility_determination = params[:eligibility_determinations].first
      eligibility_determination.merge!('yearly_expected_contribution' => nil)
      @result = subject.call(application)
      family.reload
      @thhs = family.active_household.tax_households
    end

    context 'when yearly_expected_contribution is nil' do
      it 'should successfully create thh object' do
        expect(@thhs.first).to be_a(TaxHousehold)
        expect(@thhs.first.yearly_expected_contribution).to be_nil
      end
    end
  end
end
