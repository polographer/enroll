# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/spec/shared_contexts/enrollment.rb"
require "#{Rails.root}/spec/shared_contexts/family_enrollment_renewal.rb"

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  RSpec.describe Enrollments::IndividualMarket::FamilyEnrollmentRenewal, type: :model, :dbclean => :after_each do
    include FloatHelper
    include_context "setup family initial and renewal enrollments data"

    before :all do
      DatabaseCleaner.clean
    end

    let(:ivl_benefit) { double('BenefitPackage', residency_status: ['any']) }

    before do
      allow(subject).to receive(:ivl_benefit).and_return(ivl_benefit)
    end

    subject do
      enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
      enrollment_renewal.enrollment = enrollment
      enrollment_renewal.assisted = assisted
      enrollment_renewal.aptc_values = aptc_values
      enrollment_renewal.renewal_coverage_start = renewal_benefit_coverage_period.start_on
      enrollment_renewal
    end

    before do
      TimeKeeper.set_date_of_record_unprotected!(current_date)
    end

    after :each do
      TimeKeeper.set_date_of_record_unprotected!(Date.today)
    end

    describe '#transition_enrollment' do
      let(:renewal_enrollment) { subject.renew }

      before do
        allow(subject).to receive(:subscriber_dropped?).with(anything).and_return(subscriber_dropped)
      end

      context 'when subscriber is dropped' do
        let(:subscriber_dropped) { true }

        it 'transitions renewal enrollment to coverage_selected' do
          expect(renewal_enrollment.coverage_selected?).to be_truthy
        end

        it 'creates only one expected workflow state transition' do
          expect(renewal_enrollment.workflow_state_transitions.count).to eq(1)

          expect(
            renewal_enrollment.workflow_state_transitions.pluck(:event, :from_state, :to_state)
          ).to eq([['select_coverage!', 'shopping', 'coverage_selected']])
        end
      end

      context 'when subscriber is not dropped' do
        let(:subscriber_dropped) { false }

        it 'transitions renewal enrollment to auto_renewing' do
          expect(renewal_enrollment.auto_renewing?).to be_truthy
        end

        it 'creates only one expected workflow state transition' do
          expect(renewal_enrollment.workflow_state_transitions.count).to eq(1)

          expect(
            renewal_enrollment.workflow_state_transitions.pluck(:event, :from_state, :to_state)
          ).to eq([['renew_enrollment', 'shopping', 'auto_renewing']])
        end
      end
    end

    describe '#turned_19_during_renewal_with_pediatric_only_qdp?' do
      let(:renewal_coverage_start) { renewal_benefit_coverage_period.start_on }
      let(:person) { FactoryBot.create(:person, :with_consumer_role, dob: TimeKeeper.date_of_record - dependent_age.years) }
      let(:dependent) { double('HbxEnrollmentMember', person: person) }
      let(:dependent_age) { rand(1..18) }

      context 'when slcsp feature is disabled' do
        before do
          allow(subject).to receive(:slcsp_feature_enabled?).with(renewal_coverage_start.year).and_return(false)
        end

        it 'returns false as the feature is disabled' do
          expect(
            subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
          ).to be_falsey
        end
      end

      context 'when enrollment is of coverage_kind health' do
        before do
          allow(subject).to receive(:slcsp_feature_enabled?).with(renewal_coverage_start.year).and_return(true)
        end

        it 'returns false as the enrollment is health' do
          expect(
            subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
          ).to be_falsey
        end
      end

      context 'when renewal dental product allows adult offerings' do
        let(:coverage_kind) { 'dental' }
        let(:dental_renewal_product) do
          double('::BenefitMarkets::Products::DentalProducts::DentalProduct', allows_child_only_offering?: false)
        end

        before do
          allow(subject).to receive(:slcsp_feature_enabled?).with(renewal_coverage_start.year).and_return(true)
          allow(subject).to receive(:dental_renewal_product).and_return(dental_renewal_product)
        end

        it 'returns false as the dental product allows adult offerings' do
          expect(
            subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
          ).to be_falsey
        end
      end

      context 'when member is aged less than 19 as of the renewal_coverage_start' do
        let(:coverage_kind) { 'dental' }
        let(:dental_renewal_product) do
          double('::BenefitMarkets::Products::DentalProducts::DentalProduct', allows_child_only_offering?: true)
        end

        before do
          allow(subject).to receive(:slcsp_feature_enabled?).with(renewal_coverage_start.year).and_return(true)
          allow(subject).to receive(:dental_renewal_product).and_return(dental_renewal_product)
        end

        it 'returns false as member is aged less 19' do
          expect(
            subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
          ).to be_falsey
        end
      end

      # when slcsp feature enabled
      # enrollment is dental
      # renewal dental product only offers child only
      # member is turning 19 as of renewal_coverage_start
      context 'member is ineligible for pediatric only dental renewal' do
        let(:coverage_kind) { 'dental' }
        let(:dental_renewal_product) do
          double('::BenefitMarkets::Products::DentalProducts::DentalProduct', allows_child_only_offering?: true)
        end

        before do
          allow(subject).to receive(:slcsp_feature_enabled?).with(renewal_coverage_start.year).and_return(true)
          allow(subject).to receive(:dental_renewal_product).and_return(dental_renewal_product)
        end

        context 'when member is turning 19 as of renewal_coverage_start' do
          let(:dependent_age) { 19 }

          it 'returns true as member is ineligible for pediatric only dental renewal' do
            expect(
              subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
            ).to be_truthy
          end
        end

        context 'when member is aged more than 19 as of renewal_coverage_start' do
          let(:dependent_age) { rand(20..100) }

          it 'returns true as member is ineligible for pediatric only dental renewal' do
            expect(
              subject.turned_19_during_renewal_with_pediatric_only_qdp?(dependent)
            ).to be_truthy
          end
        end
      end
    end

    describe "#clone_enrollment_members" do

      context "when dependent age off feature is turned off" do
        before do
          allow(child1).to receive(:relationship).and_return('child')
          allow(child2).to receive(:relationship).and_return('child')
          allow(EnrollRegistry[:age_off_relaxed_eligibility].feature).to receive(:is_enabled).and_return(false)
        end
        context "When a child is aged off" do
          it "should not include child" do

            applicant_ids = subject.clone_enrollment_members.collect(&:applicant_id)

            expect(applicant_ids).to include(family.primary_applicant.id)
            expect(applicant_ids).to include(spouse.id)
            expect(applicant_ids).not_to include(child1.id)
            expect(applicant_ids).to include(child2.id)
          end

          it "should generate passive renewal in auto_renewing state" do
            renewal = subject.renew
            expect(renewal.auto_renewing?).to be_truthy
          end
        end
      end

      context "when dependent age off feature is turned on" do
        let(:enrollment_with_tobacco_users) do
          FactoryBot.create(:hbx_enrollment,
                            :with_tobacco_use_enrollment_members,
                            family: family,
                            enrollment_members: enrollment_members,
                            household: family.active_household,
                            coverage_kind: coverage_kind,
                            effective_on: current_benefit_coverage_period.start_on,
                            kind: "individual",
                            product_id: current_product.id,
                            rating_area_id: rating_area.id,
                            consumer_role_id: family.primary_person.consumer_role.id,
                            aasm_state: 'coverage_selected')
        end
        before do
          allow(child1).to receive(:relationship).and_return('child')
          allow(child3).to receive(:relationship).and_return('child')
          allow(EnrollRegistry[:age_off_relaxed_eligibility].feature).to receive(:is_enabled).and_return(true)
        end

        context 'children aged above 26' do
          before do
            child1.person.update_attributes!(dob: TimeKeeper.date_of_record - 27.years)
            child2.person.update_attributes!(dob: TimeKeeper.date_of_record - 21.years)
          end

          context 'age_off_excluded for children set to true' do
            before do
              update_age_off_excluded(family, true)
            end

            it 'should include child1' do
              expect(subject.renew.hbx_enrollment_members.map(&:applicant_id)).to include(child1.id)
              expect(subject.renew.hbx_enrollment_members.map(&:applicant_id)).to include(child2.id)
            end
          end

          context 'age_off_excluded for children set to false' do
            before do
              update_age_off_excluded(family, false)
            end

            it 'should not include child1' do
              expect(subject.renew.hbx_enrollment_members.map(&:applicant_id)).not_to include(child1.id)
              expect(subject.renew.hbx_enrollment_members.map(&:applicant_id)).to include(child2.id)
            end
          end
        end

        context "When a child is aged off" do
          it "should include child" do
            applicant_ids = subject.clone_enrollment_members.collect(&:applicant_id)
            expect(applicant_ids).to include(family.primary_applicant.id)
            expect(applicant_ids).not_to include(child1.id)
            expect(applicant_ids).to include(child3.id)
          end

          it "should generate passive renewal" do
            renewal = subject.renew
            expect(renewal.auto_renewing?).to be_truthy
            expect(renewal.effective_on).to eq renewal_benefit_coverage_period.start_on
          end

          it 'Renewal enrollment members should have the tobacco_use populated from previous enrollment' do
            subject.enrollment = enrollment_with_tobacco_users
            renewal_members = subject.clone_enrollment_members
            expect(renewal_members.pluck(:tobacco_use)).to include('Y')
          end

          it 'Renewal enrollment members should have the tobacco_use populated N for unknown.' do
            renewal_members = subject.clone_enrollment_members
            expect(renewal_members.pluck(:tobacco_use).uniq).to eq(['N'])
          end
        end
      end

      # Don't we need this for all the dependents
      # Are we using is_disabled flag in the system
      context "When a child person record is disabled" do
        let(:spouse_person) { FactoryBot.create(:person, dob: spouse_dob, is_disabled: true) }

        it "should not include child person record" do
          applicant_ids = subject.clone_enrollment_members.collect(&:applicant_id)
          expect(applicant_ids).not_to include(spouse.id)
        end
      end

      context "all ineligible members" do
        before do
          enrollment.hbx_enrollment_members.each do |member|
            member.person.update_attributes(is_disabled: true)
          end
        end

        it "should raise an error" do
          expect { subject.clone_enrollment_members }.to raise_error(RuntimeError, /Unable to generate renewal for enrollment with hbx_id/)
        end
      end
    end

    describe "#renew" do

      before do
        allow(child1).to receive(:relationship).and_return('child')
        allow(child2).to receive(:relationship).and_return('child')
      end

      context "when all the covered housedhold eligible for renewal" do
        let(:child1_dob) { current_date.next_month - 24.years }


        it "should generate passive renewal in auto_renewing state" do
          renewal = subject.renew
          expect(renewal.auto_renewing?).to be_truthy
        end

        it 'should trigger enr notice' do
          expect_any_instance_of(::HbxEnrollment).to receive(:trigger_enrollment_notice)
          subject.renew
        end
      end

      context "renew coverall product" do
        subject do
          enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
          enrollment_renewal.enrollment = coverall_enrollment
          enrollment_renewal.assisted = assisted
          enrollment_renewal.aptc_values = aptc_values
          enrollment_renewal.renewal_coverage_start = renewal_benefit_coverage_period.start_on
          enrollment_renewal
        end

        it "should generate passive renewal for coverall enrollment in auto renewing state" do
          renewal = subject.renew
          expect(renewal.auto_renewing?).to be_truthy
        end

        it "should generate passive renewal for coverall enrollment and assign resident role" do
          renewal = subject.renew
          expect(renewal.kind).to eq('coverall')
          expect(renewal.resident_role_id.present?).to eq true
        end
      end

      context "when renewal rating area doesn't exist" do
        before do
          renewal_rating_area.destroy!
        end

        it 'returns error message and log the error' do
          expect_any_instance_of(Logger).to receive(:info).with(/Enrollment renewal failed for #{enrollment.hbx_id} with error message: /i)
          expect(subject.renew).to eq(
            "Cannot renew enrollment #{enrollment.hbx_id}. Error: Rating Area Is Blank"
          )
        end
      end

      context "when renewal service area doesn't exist" do
        before do
          renewal_service_area.destroy!
        end

        it 'returns error message and log the error' do
          expect_any_instance_of(Logger).to receive(:info).with(/Enrollment renewal failed for #{enrollment.hbx_id} with error message: /i)
          expect(subject.renew).to eq(
            "Cannot renew enrollment #{enrollment.hbx_id}. Error: Product is NOT offered in service area"
          )
        end
      end

      context "when consumer covered under catastrophic product" do
        before do
          primary.update(dob: renewal_benefit_coverage_period.start_on - 25.years)
          spouse.person.update(dob: renewal_benefit_coverage_period.start_on - 25.years)
          child1.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
          child2.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
          child3.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
        end

        let!(:current_product) { FactoryBot.create(:active_individual_catastophic_product, hios_id: "11111111122302-01", csr_variant_id: "01", renewal_product_id: renewal_product.id) }
        it 'should return an empty apt hash' do
          allow(::Operations::PremiumCredits::FindAptc).to receive(:new).and_return(
            double(
              call: double(
                success?: true,
                value!: 100
              )
            )
          )
          expect(subject.renew.applied_aptc_amount).to be_zero
        end
      end

      context 'when mthh enabled' do
        before do
          allow(UnassistedPlanCostDecorator).to receive(:new).and_return(double(total_ehb_premium: 1390, total_premium: 1390))
          allow(EnrollRegistry[:temporary_configuration_enable_multi_tax_household_feature].feature).to receive(:is_enabled).and_return(true)
          update_age_off_excluded(enrollment.family, false)
        end

        let(:assisted) { false }
        let(:aptc_values) { {} }

        subject do
          enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
          enrollment_renewal.enrollment = enrollment
          enrollment_renewal.assisted = assisted
          enrollment_renewal.aptc_values = aptc_values
          enrollment_renewal.renewal_coverage_start = renewal_benefit_coverage_period.start_on
          enrollment_renewal
        end

        context 'unassisted renewal' do

          it 'will not set aptc values & will generate renewal' do
            renewal = subject.renew
            expect(renewal.is_a?(HbxEnrollment)).to eq true
            expect(subject.aptc_values).to eq({
                                                csr_amt: 0,
                                                applied_percentage: 0.85,
                                                applied_aptc: 0.0,
                                                max_aptc: 0.0,
                                                ehb_premium: 1390
                                              })
          end
        end

        context 'unassisted renewal with all AI AN members' do
          let!(:renewal_health_product_03) do
            prod =
              FactoryBot.create(:benefit_markets_products_health_products_health_product, :with_issuer_profile,
                                benefit_market_kind: :aca_individual, kind: :health, service_area: renewal_service_area, csr_variant_id: '03',
                                metal_level_kind: 'silver', hios_id: "#{enrollment.product.renewal_product.hios_base_id}-03",
                                application_period: renewal_application_period)
            prod.premium_tables = [renewal_premium_table]
            prod.save
            prod
          end

          before do
            enrollment.family.primary_person.update_attributes!(tribal_id: '123456789', tribal_state: 'ME')
            enrollment.hbx_enrollment_members = [enrollment.hbx_enrollment_members.first]
            enrollment.save!
          end

          it 'will generate renewal with CSR variant 03' do
            renewal = subject.renew
            expect(renewal.product.csr_variant_id).to eq('03')
            expect(renewal.product.id).to eq(renewal_health_product_03.id)
            expect(subject.aptc_values).to eq({
                                                csr_amt: 'limited',
                                                applied_percentage: 0.85,
                                                applied_aptc: 0.0,
                                                max_aptc: 0.0,
                                                ehb_premium: 1390
                                              })
          end
        end

        context 'unassisted renewal one AI AN member and others non-AI AN members' do
          before do
            enrollment.family.primary_person.update_attributes!(tribal_id: '123456789', tribal_state: 'ME')
          end

          it 'will generate renewal with CSR variant' do
            renewal = subject.renew
            expect(renewal.is_a?(HbxEnrollment)).to eq true
            expect(subject.aptc_values).to eq({
                                                csr_amt: 0,
                                                applied_percentage: 0.85,
                                                applied_aptc: 0.0,
                                                max_aptc: 0.0,
                                                ehb_premium: 1390
                                              })
          end

          it 'populates predecessor_enrollment_id for health enrollments' do
            expect(
              subject.renew.predecessor_enrollment_id
            ).to eq(enrollment.id)
          end
        end

        context 'assisted renewal' do
          before do
            allow(::Operations::BenchmarkProducts::IdentifySlcspWithPediatricDentalCosts).to receive(:new).and_return(
              double('IdentifySlcspWithPediatricDentalCosts',
                     call: double(:value! => slcsp_info, :success? => true))
            )
          end

          let(:family) do
            family = FactoryBot.build(:family, person: primary)
            family.family_members = [
              FactoryBot.build(:family_member, is_primary_applicant: true, is_active: true, family: family, person: primary),
              FactoryBot.build(:family_member, is_primary_applicant: false, is_active: true, family: family, person: dependent)
            ]

            family.person.person_relationships.push PersonRelationship.new(relative_id: dependent.id, kind: 'spouse')
            family.save
            family
          end

          let(:dependent) { FactoryBot.create(:person, :with_consumer_role) }
          let(:primary) { FactoryBot.create(:person, :with_consumer_role) }
          let(:primary_applicant) { family.primary_applicant }
          let(:dependents) { family.dependents }

          let(:tax_household_group) do
            family.tax_household_groups.create!(
              assistance_year: TimeKeeper.date_of_record.year,
              source: 'Admin',
              start_on: TimeKeeper.date_of_record.beginning_of_year,
              tax_households: [
                FactoryBot.build(:tax_household, household: family.active_household)
              ]
            )
          end

          let(:tax_household) do
            tax_household_group.tax_households.first
          end

          let(:aptc_grant) { eligibility_determination.grants.first }

          let(:enrollment) do
            FactoryBot.create(:hbx_enrollment,
                              :individual_shopping,
                              :with_silver_health_product,
                              :with_enrollment_members,
                              product_id: current_product.id,
                              enrollment_members: [primary_applicant],
                              consumer_role_id: primary.consumer_role.id,
                              family: family)
          end

          let(:benchmark_premium) { primary_bp }

          let(:yearly_expected_contribution) { 125.00 * 12 }

          let(:slcsp_info) do
            OpenStruct.new(
              households: [OpenStruct.new(
                household_id: aptc_grant.tax_household_id,
                household_benchmark_ehb_premium: benchmark_premium,
                members: family.family_members.collect do |fm|
                  OpenStruct.new(
                    family_member_id: fm.id.to_s,
                    relationship_with_primary: fm.primary_relationship,
                    date_of_birth: fm.dob,
                    age_on_effective_date: fm.age_on(TimeKeeper.date_of_record)
                  )
                end
              )]
            )
          end

          let(:primary_bp) { 500.00 }
          let(:dependent_bp) { 600.00 }

          context 'when renewal grants not present' do
            let!(:eligibility_determination) do
              determination = family.create_eligibility_determination(effective_date: TimeKeeper.date_of_record.beginning_of_year)
              determination.grants.create(
                key: "AdvancePremiumAdjustmentGrant",
                value: yearly_expected_contribution,
                start_on: TimeKeeper.date_of_record.beginning_of_year,
                end_on: TimeKeeper.date_of_record.end_of_year,
                assistance_year: TimeKeeper.date_of_record.year,
                member_ids: family.family_members.map(&:id).map(&:to_s),
                tax_household_id: tax_household.id
              )

              determination
            end

            it 'will not set aptc values & will generate renewal' do
              renewal = subject.renew
              expect(renewal.is_a?(HbxEnrollment)).to eq true
              expect(subject.aptc_values).to eq({
                                                  csr_amt: 0,
                                                  applied_percentage: 0.85,
                                                  applied_aptc: 0.0,
                                                  max_aptc: 0.0,
                                                  ehb_premium: 1390
                                                })
            end
          end

          context 'when renewal grants present' do
            let(:max_aptc) { 375.0 }

            let!(:tax_household_group) do
              family.tax_household_groups.create!(
                assistance_year: TimeKeeper.date_of_record.year + 1,
                source: 'Admin',
                start_on: TimeKeeper.date_of_record.beginning_of_year.next_year,
                tax_households: [
                  FactoryBot.build(:tax_household, household: family.active_household)
                ]
              )
            end

            let!(:eligibility_determination) do
              create_eligibility_determination(family, yearly_expected_contribution, tax_household)
            end

            it 'will set aptc values & will generate renewal' do
              allow(::Operations::PremiumCredits::FindAptc).to receive(:new).and_return(
                double(
                  call: double(
                    success?: true,
                    value!: max_aptc
                  )
                )
              )
              create_eligibility_determination(family, yearly_expected_contribution, tax_household) if enrollment.family.eligibility_determination.reload.grants.count.zero?

              renewal = subject.renew
              expect(renewal.is_a?(HbxEnrollment)).to eq true
              expect(subject.aptc_values).to eq({
                                                  csr_amt: 0,
                                                  applied_percentage: 0.85,
                                                  applied_aptc: 318.75,
                                                  max_aptc: 375,
                                                  ehb_premium: 1390
                                                })
              expect(subject.assisted).to eq true
            end
          end
        end

        context "when consumer covered under catastrophic product" do
          before do
            primary.update(dob: renewal_benefit_coverage_period.start_on - 25.years)
            spouse.person.update(dob: renewal_benefit_coverage_period.start_on - 25.years)
            child1.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
            child2.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
            child3.person.update(dob: renewal_benefit_coverage_period.start_on - 1.years)
            renewal_product.update(metal_level_kind: :catastrophic)
          end

          # let!(:renewal_product) { FactoryBot.create(:active_individual_catastophic_product, hios_id: "11111111122302-01", csr_variant_id: "01") }
          let!(:current_product) { FactoryBot.create(:active_individual_catastophic_product, hios_id: "11111111122302-01", csr_variant_id: "01", renewal_product_id: renewal_product.id) }

          it 'should return an empty apt hash' do
            allow(::Operations::PremiumCredits::FindAptc).to receive(:new).and_return(
              double(
                call: double(
                  success?: true,
                  value!: 100
                )
              )
            )
            expect(subject.renew.applied_aptc_amount).to be_zero
          end
        end
      end

      context 'when mthh enabled for dental enrollment' do
        let!(:dental_product) do
          prod =
            FactoryBot.create(
              :benefit_markets_products_health_products_health_product,
              :with_issuer_profile,
              benefit_market_kind: :aca_individual,
              kind: :dental,
              service_area: service_area,
              csr_variant_id: '01',
              metal_level_kind: 'silver',
              hios_id: '11111111122302-01',
              renewal_product_id: dental_renewal_product.id,
              application_period: application_period
            )
          prod.premium_tables = [premium_table]
          prod.save
          prod
        end

        let!(:dental_renewal_product) do
          prod =
            FactoryBot.create(
              :benefit_markets_products_health_products_health_product,
              :with_issuer_profile,
              benefit_market_kind: :aca_individual,
              kind: :dental,
              service_area: renewal_service_area,
              csr_variant_id: '01',
              metal_level_kind: 'silver',
              hios_id: '11111111122302-01',
              application_period: renewal_application_period
            )
          prod.premium_tables = [renewal_premium_table]
          prod.save
          prod
        end

        let(:assisted) { false }
        let(:aptc_values) { {} }

        subject do
          enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
          enrollment_renewal.enrollment = enrollment
          enrollment_renewal.assisted = assisted
          enrollment_renewal.aptc_values = aptc_values
          enrollment_renewal.renewal_coverage_start = renewal_benefit_coverage_period.start_on
          enrollment_renewal
        end

        before do
          enrollment.coverage_kind = "dental"
          enrollment.product = dental_product
          enrollment.save!
          allow(EnrollRegistry[:temporary_configuration_enable_multi_tax_household_feature].feature).to receive(:is_enabled).and_return(true)
        end

        context 'unassisted renewal' do
          it 'will not set aptc values & will generate renewal' do
            renewal = subject.renew
            expect(renewal.is_a?(HbxEnrollment)).to eq true
            expect(subject.aptc_values).to eq({})
          end

          it 'populates predecessor_enrollment_id for dental enrollments' do
            expect(
              subject.renew.predecessor_enrollment_id
            ).to eq(enrollment.id)
          end
        end

        context 'assisted renewal' do
          before do
            allow(::Operations::BenchmarkProducts::IdentifySlcspWithPediatricDentalCosts).to receive(:new).and_return(
              double('IdentifySlcspWithPediatricDentalCosts',
                     call: double(:value! => slcsp_info, :success? => true))
            )
          end

          let(:family) do
            family = FactoryBot.build(:family, person: primary)
            family.family_members = [
              FactoryBot.build(:family_member, is_primary_applicant: true, is_active: true, family: family, person: primary),
              FactoryBot.build(:family_member, is_primary_applicant: false, is_active: true, family: family, person: dependent)
            ]

            family.person.person_relationships.push PersonRelationship.new(relative_id: dependent.id, kind: 'spouse')
            family.save
            family
          end

          let(:dependent) { FactoryBot.create(:person, :with_consumer_role) }
          let(:primary) { FactoryBot.create(:person, :with_consumer_role) }
          let(:primary_applicant) { family.primary_applicant }
          let(:dependents) { family.dependents }

          let(:tax_household_group) do
            family.tax_household_groups.create!(
              assistance_year: TimeKeeper.date_of_record.year,
              source: 'Admin',
              start_on: TimeKeeper.date_of_record.beginning_of_year,
              tax_households: [
                FactoryBot.build(:tax_household, household: family.active_household)
              ]
            )
          end

          let(:tax_household) do
            tax_household_group.tax_households.first
          end

          let(:aptc_grant) { eligibility_determination.grants.first }

          let(:enrollment) do
            FactoryBot.create(:hbx_enrollment,
                              :individual_shopping,
                              :with_silver_health_product,
                              :with_enrollment_members,
                              product_id: current_product.id,
                              enrollment_members: [primary_applicant],
                              consumer_role_id: primary.consumer_role.id,
                              family: family)
          end

          let(:benchmark_premium) { primary_bp }

          let(:yearly_expected_contribution) { 125.00 * 12 }

          let(:slcsp_info) do
            OpenStruct.new(
              households: [OpenStruct.new(
                household_id: aptc_grant.tax_household_id,
                household_benchmark_ehb_premium: benchmark_premium,
                members: family.family_members.collect do |fm|
                  OpenStruct.new(
                    family_member_id: fm.id.to_s,
                    relationship_with_primary: fm.primary_relationship,
                    date_of_birth: fm.dob,
                    age_on_effective_date: fm.age_on(TimeKeeper.date_of_record)
                  )
                end
              )]
            )
          end

          let(:primary_bp) { 500.00 }
          let(:dependent_bp) { 600.00 }

          context 'when renewal grants not present' do
            let!(:eligibility_determination) do
              determination = family.create_eligibility_determination(effective_date: TimeKeeper.date_of_record.beginning_of_year)
              determination.grants.create(
                key: "AdvancePremiumAdjustmentGrant",
                value: yearly_expected_contribution,
                start_on: TimeKeeper.date_of_record.beginning_of_year,
                end_on: TimeKeeper.date_of_record.end_of_year,
                assistance_year: TimeKeeper.date_of_record.year,
                member_ids: family.family_members.map(&:id).map(&:to_s),
                tax_household_id: tax_household.id
              )

              determination
            end

            it 'will not set aptc values & will generate renewal' do
              renewal = subject.renew
              expect(renewal.is_a?(HbxEnrollment)).to eq true
              expect(subject.aptc_values).to eq({})
            end
          end

          context 'when renewal grants present' do
            let!(:eligibility_determination) do
              determination = family.create_eligibility_determination(effective_date: TimeKeeper.date_of_record.beginning_of_year)
              determination.grants.create(
                key: "AdvancePremiumAdjustmentGrant",
                value: yearly_expected_contribution,
                start_on: TimeKeeper.date_of_record.beginning_of_year,
                end_on: TimeKeeper.date_of_record.end_of_year,
                assistance_year: TimeKeeper.date_of_record.year,
                member_ids: family.family_members.map(&:id).map(&:to_s),
                tax_household_id: tax_household.id
              )

              determination.grants.create(
                key: "AdvancePremiumAdjustmentGrant",
                value: yearly_expected_contribution,
                start_on: TimeKeeper.date_of_record.beginning_of_year.next_year,
                end_on: TimeKeeper.date_of_record.end_of_year.next_year,
                assistance_year: TimeKeeper.date_of_record.year + 1,
                member_ids: family.family_members.map(&:id).map(&:to_s),
                tax_household_id: tax_household.id
              )

              determination
            end

            it 'will not set aptc values & will generate renewal' do
              renewal = subject.renew
              expect(renewal.is_a?(HbxEnrollment)).to eq true
              expect(subject.aptc_values).to eq({ })
              expect(subject.assisted).to be_falsey
            end
          end
        end
      end

      context 'osse unassisted enrollment renewal' do

        before do
          allow_any_instance_of(BenefitMarkets::Products::HealthProducts::HealthProduct).to receive(:is_hc4cc_plan).and_return(true)
          BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
        end

        let(:child1_dob) { current_date.next_month - 24.years }

        context 'when osse eligibility present for renewal year' do
          it "should renew and apply child care subsidy" do
            allow_any_instance_of(HbxEnrollment).to receive(:ivl_osse_eligible?).and_return(true)
            allow_any_instance_of(HbxEnrollment).to receive(:is_eligible_for_osse_grant?).and_return(true)
            enrollment.update_osse_childcare_subsidy
            expect(enrollment.product.is_hc4cc_plan).to be_truthy
            expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0

            renewal = subject.renew
            expect(renewal.auto_renewing?).to be_truthy
            expect(renewal.product.is_hc4cc_plan).to be_truthy
            expect(renewal.eligible_child_care_subsidy.to_f).to be > 0
            expect(renewal.eligible_child_care_subsidy.to_f).to eq(renewal.total_premium.to_f)
          end
        end

        context 'when osse eligibility not present for renewal year' do

          it "should renew and don't apply child care subsidy" do
            allow_any_instance_of(HbxEnrollment).to receive(:ivl_osse_eligible?).and_return(true)
            allow(enrollment).to receive(:is_eligible_for_osse_grant?).and_return(true)
            enrollment.update_osse_childcare_subsidy
            expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0

            renewal = subject.renew
            expect(renewal.auto_renewing?).to be_truthy
            expect(renewal.eligible_child_care_subsidy.to_f).to eq(0.0)
          end
        end
      end

      context 'osse assisted enrollment renewal' do

        let(:assisted) { true }
        let(:aptc_values) do
          {
            applied_percentage: 0.75,
            applied_aptc: 547.5,
            max_aptc: 730.0,
            csr_amt: 73
          }
        end
        let(:child1_dob) { current_date.next_month - 24.years }

        before do
          BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
          allow_any_instance_of(BenefitMarkets::Products::HealthProducts::HealthProduct).to receive(:is_hc4cc_plan).and_return(true)
        end

        context 'when osse eligibility present for renewal year' do
          before do
            allow_any_instance_of(HbxEnrollment).to receive(:ivl_osse_eligible?).and_return(true)
            allow_any_instance_of(HbxEnrollment).to receive(:is_eligible_for_osse_grant?).and_return(true)
            allow(EnrollRegistry).to receive(:feature_enabled?).with(:temporary_configuration_enable_multi_tax_household_feature).and_return(true)
            allow(EnrollRegistry).to receive(:feature_enabled?).with("aca_ivl_osse_eligibility_#{enrollment.effective_on.year}").and_return(false)
            allow(EnrollRegistry).to receive(:feature_enabled?).with(:total_minimum_responsibility).and_return(false)
            enrollment.update_osse_childcare_subsidy
          end

          context 'when osse minimum aptc enabled' do
            before do
              allow(subject).to receive(:osse_aptc_minimum_enabled?).and_return(true)
              allow(subject).to receive(:minimum_applied_aptc_pct_for_osse).and_return(0.85)
              allow(subject).to receive(:can_renew_assisted_product?).and_return(true)
              allow(subject).to receive(:eligible_to_get_covered?).and_return(true)
              allow(subject).to receive(:populate_aptc_hash).and_return(true)
              allow(subject).to receive(:subscriber_dropped?).and_return(false)
            end

            it "should renew and apply child care subsidy" do
              expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0
              renewal = subject.renew
              expect(renewal.auto_renewing?).to be_truthy
              expect(renewal.eligible_child_care_subsidy.to_f).to be > 0
              expect(renewal.eligible_child_care_subsidy.to_f).to eq(renewal.total_premium.to_f - renewal.applied_aptc_amount.to_f)
            end

            it "should apply minimum aptc pct" do
              expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0
              renewal = subject.renew
              expect(renewal.auto_renewing?).to be_truthy
              expect(renewal.elected_aptc_pct).to be 0.85
              expect(renewal.applied_aptc_amount.to_f).to eq(730.0 * 0.85)
            end
          end

          context 'when osse minimum aptc not enabled' do
            before do
              allow(subject).to receive(:osse_aptc_minimum_enabled?).and_return(false)
              allow(subject).to receive(:minimum_applied_aptc_pct_for_osse).and_return(0.85)
              allow(subject).to receive(:can_renew_assisted_product?).and_return(true)
              allow(subject).to receive(:eligible_to_get_covered?).and_return(true)
              allow(subject).to receive(:populate_aptc_hash).and_return(true)
              allow(subject).to receive(:subscriber_dropped?).and_return(false)
            end

            it "should renew and apply child care subsidy" do
              expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0
              renewal = subject.renew
              expect(renewal.auto_renewing?).to be_truthy
              expect(renewal.eligible_child_care_subsidy.to_f).to be > 0
              expect(renewal.eligible_child_care_subsidy.to_f).to eq(renewal.total_premium.to_f - renewal.applied_aptc_amount.to_f)
            end

            it "should not apply minimum aptc pct" do
              expect(enrollment.eligible_child_care_subsidy.to_f).to be > 0
              renewal = subject.renew
              expect(renewal.auto_renewing?).to be_truthy
              expect(renewal.elected_aptc_pct).to be 0.75
              expect(renewal.applied_aptc_amount.to_f).to eq(730.0 * 0.75)
            end
          end
        end
      end
    end

    describe ".renewal_product" do
      context "When consumer covered under catastrophic product" do
        let!(:renewal_cat_age_off_product) { FactoryBot.create(:renewal_ivl_silver_health_product,  hios_base_id: "94506DC0390010", hios_id: "94506DC0390010-01", csr_variant_id: "01") }
        let!(:renewal_product) { FactoryBot.create(:renewal_individual_catastophic_product, hios_id: "11111111122302-01", csr_variant_id: "01") }
        let!(:current_product) { FactoryBot.create(:active_individual_catastophic_product, hios_id: "11111111122302-01", csr_variant_id: "01", renewal_product_id: renewal_product.id, catastrophic_age_off_product_id: renewal_cat_age_off_product.id) }

        let(:enrollment_members) { [child1, child2] }

        context "When one of the covered individuals aged off(30 years)" do
          let(:child1_dob) { current_date.next_month - 30.years }

          it "should return catastrophic aged off product" do
            expect(subject.renewal_product).to eq renewal_cat_age_off_product.id
          end
        end

        context "When all the covered individuals under 30" do
          let(:child1_dob) { current_date.next_month - 25.years }

          it "should return renewal product" do
            expect(subject.renewal_product).to eq renewal_product.id
          end
        end

        context "renew a current product to specific product" do
          subject do
            enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
            enrollment_renewal.enrollment = catastrophic_enrollment
            enrollment_renewal.assisted = assisted
            enrollment_renewal.aptc_values = aptc_values
            enrollment_renewal.renewal_coverage_start = Date.new(Date.current.year + 1,1,1)
            enrollment_renewal
          end
          let(:child1_dob) { current_date.next_month - 30.years }

          it "should return new renewal product" do
            expect(subject.renewal_product).to eq renewal_cat_age_off_product.id
          end
        end
      end

      context "When consumer covered under catastrophic product with assisted" do
        before do
          current_cat_product.update_attributes!(hios_base_id: nil, catastrophic_age_off_product_id: renewal_cat_age_off_product.id)
          allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate) {|_id, _start, age| age * 1.0}
        end
        let!(:tax_household) { FactoryBot.create(:tax_household, household: family.active_household, effective_ending_on: nil, effective_starting_on: Date.new(Date.current.year + 1,1,1))}
        let!(:thh_member) { FactoryBot.create(:tax_household_member, applicant_id: family.primary_applicant.id, tax_household: tax_household, csr_eligibility_kind: "csr_73")}
        let!(:thh_member2) { FactoryBot.create(:tax_household_member, applicant_id: child1.id, tax_household: tax_household, csr_eligibility_kind: "csr_73")}
        let!(:thh_member3) { FactoryBot.create(:tax_household_member, applicant_id: child2.id, tax_household: tax_household, csr_eligibility_kind: "csr_73")}
        let!(:eligibilty_determination) { FactoryBot.create(:eligibility_determination, max_aptc: 500.00, tax_household: tax_household)}

        let!(:catastrophic_ivl_enrollment) do
          FactoryBot.create(:hbx_enrollment,
                            :with_enrollment_members,
                            family: family,
                            enrollment_members: enrollment_members,
                            household: family.active_household,
                            coverage_kind: coverage_kind,
                            consumer_role_id: family.primary_person.consumer_role.id,
                            effective_on: Date.new(Date.current.year,1,1),
                            kind: "individual",
                            product_id: current_cat_product.id,
                            aasm_state: 'coverage_selected')
        end
        let!(:renewal_cat_age_off_product) do
          prod = FactoryBot.create(:renewal_ivl_silver_health_product,  hios_base_id: "94506DC0390010", hios_id: "94506DC0390010-01", csr_variant_id: "01", service_area: renewal_service_area)
          prod.premium_tables = [renewal_premium_table]
          prod.save
          prod
        end
        let(:renewal_premium_table)  { build(:benefit_markets_products_premium_table, effective_period: renewal_application_period, rating_area: renewal_rating_area) }
        let(:enrollment_members) { [child1, child2] }

        context "renew a current product to specific product with aptc > 0" do
          subject do
            enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
            enrollment_renewal.enrollment = catastrophic_ivl_enrollment
            enrollment_renewal.assisted = true
            enrollment_renewal.aptc_values = {:applied_percentage => 1, :applied_aptc => 730.0, :max_aptc => 730.0, :csr_amt => 73}
            enrollment_renewal.renewal_coverage_start = Date.new(Date.current.year + 1,1,1)
            enrollment_renewal
          end
          let(:child1_dob) { current_date.next_month - 30.years }

          it "should return new renewal product with applied aptc" do
            expect(subject.renew.applied_aptc_amount.to_f > 0.0).to be_truthy
          end

          it "should return new renewal enrollment without catastrophic product" do
            expect(subject.renew.product.metal_level_kind).not_to be :catastrophic
          end
        end

        context "renew a current product to specific product with zero aptc" do
          subject do
            enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
            enrollment_renewal.enrollment = catastrophic_ivl_enrollment
            enrollment_renewal.assisted = true
            enrollment_renewal.aptc_values = {:applied_percentage => 1, :applied_aptc => 0, :max_aptc => 0, :csr_amt => 73}
            enrollment_renewal.renewal_coverage_start = Date.new(Date.current.year + 1,1,1)
            enrollment_renewal
          end
          let(:child1_dob) { current_date.next_month - 30.years }

          it "should return new renewal product without applied aptc" do
            expect(subject.renew.applied_aptc_amount.to_f).to eq 0.0
          end

          it "should return new renewal enrollment without catastrophic product" do
            expect(subject.renew.product.metal_level_kind).not_to be :catastrophic
          end
        end
      end
    end

    describe ".assisted_renewal_product", dbclean: :after_each do
      context "When individual currently enrolled under CSR product" do
        let!(:renewal_product) { FactoryBot.create(:renewal_ivl_silver_health_product,  hios_id: "11111111122302-04", hios_base_id: "11111111122302", csr_variant_id: "04") }
        let!(:current_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-04", hios_base_id: "11111111122302", csr_variant_id: "04", renewal_product_id: renewal_product.id) }
        let!(:csr_product) { FactoryBot.create(:renewal_ivl_silver_health_product, hios_id: "11111111122302-05", hios_base_id: "11111111122302", csr_variant_id: "05") }
        let!(:csr_01_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-01", hios_base_id: "11111111122302", csr_variant_id: "01") }
        let!(:csr_02_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-02", hios_base_id: "11111111122302", csr_variant_id: "02") }
        let!(:csr_03_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-03", hios_base_id: "11111111122302", csr_variant_id: "03") }

        context "and have different CSR amount for renewal product year" do
          let(:aptc_values) {{ csr_amt: "87" }}

          it "should be renewed into new CSR variant product" do
            expect(subject.assisted_renewal_product).to eq csr_product.id
          end
        end

        context 'all bronze products, csr: 0' do
          let(:aptc_values) {{ csr_amt: "0" }}

          before { ::BenefitMarkets::Products::HealthProducts::HealthProduct.silver_plans.update_all(metal_level_kind: :bronze) }

          it 'should be renewed into new product with CSR variant 01' do
            expect(subject.assisted_renewal_product).to eq csr_01_product.id
          end
        end

        context "and aptc value didn't gave in renewal input CSV" do
          let(:family_enrollment_instance) { Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new}

          it "should return renewal product id" do
            family_enrollment_instance.enrollment = enrollment
            family_enrollment_instance.aptc_values = {}
            expect(family_enrollment_instance.assisted_renewal_product).to eq renewal_product.id
          end
        end

        context "and have CSR amount as 0 for renewal product year" do
          let(:aptc_values) {{ csr_amt: "0" }}

          it "should map to csr variant 01 product" do
            expect(subject.assisted_renewal_product).to eq csr_01_product.id
          end
        end

        context "and have same CSR amount for renewal product year" do
          let(:aptc_values) {{ csr_amt: "73" }}

          it "should be renewed into same CSR variant product" do
            expect(subject.assisted_renewal_product).to eq renewal_product.id
          end
        end

        context "when eligible CSR variant is 02 and 03 for renewal product year" do
          before do
            enrollment.product.update_attributes(metal_level_kind: 'gold')
          end

          context 'when eligible csr is 100' do
            let(:aptc_values) {{ csr_amt: "100" }}

            it "should be renewed into eligible CSR variant product" do
              expect(subject.assisted_renewal_product).to eq csr_02_product.id
            end
          end

          context 'when eligible csr is limited' do
            let(:aptc_values) {{ csr_amt: "limited" }}

            it "should be renewed into eligible CSR variant product" do
              expect(subject.assisted_renewal_product).to eq csr_03_product.id
            end
          end
        end
      end

      context "When individual not enrolled under CSR product" do
        let!(:renewal_product) { FactoryBot.create(:renewal_ivl_gold_health_product, hios_id: "11111111122302-01", csr_variant_id: "01") }
        let!(:current_product) { FactoryBot.create(:active_ivl_gold_health_product, hios_id: "11111111122302-01", csr_variant_id: "01", renewal_product_id: renewal_product.id) }

        it "should return regular renewal product" do
          expect(subject.assisted_renewal_product).to eq renewal_product.id
        end
      end

      context "when individual has CSR change" do
        let!(:renewal_product) { FactoryBot.create(:renewal_ivl_silver_health_product,  hios_id: "11111111122302-04", hios_base_id: "11111111122302", csr_variant_id: "04") }
        let!(:current_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-04", hios_base_id: "11111111122302", csr_variant_id: "04", renewal_product_id: renewal_product.id) }
        let!(:csr_product) { FactoryBot.create(:renewal_ivl_silver_health_product, hios_id: "11111111122302-05", hios_base_id: "11111111122302", csr_variant_id: "05") }
        let!(:csr_01_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-01", hios_base_id: "11111111122302", csr_variant_id: "01") }
        let!(:csr_02_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-02", hios_base_id: "11111111122302", csr_variant_id: "02") }
        let!(:csr_03_product) { FactoryBot.create(:active_ivl_silver_health_product, hios_id: "11111111122302-03", hios_base_id: "11111111122302", csr_variant_id: "03") }
        let(:aptc_values) {{ csr_amt: "94" }}

        before :each do
          ::BenefitMarkets::Products::HealthProducts::HealthProduct.silver_plans.update_all(metal_level_kind: :bronze)
          enrollment.product.update_attributes!(renewal_product_id: renewal_product.id)
        end
        it "should default to 01 variant if no other plan found" do
          expect(subject.assisted_renewal_product).to eq csr_01_product.id
        end
      end
    end

    describe ".clone_enrollment" do
      context "For QHP enrollment" do
        it "should set enrollment atrributes" do
        end
      end

      context "Assisted enrollment" do
        include_context "setup families enrollments"

        subject do
          enrollment_renewal = Enrollments::IndividualMarket::FamilyEnrollmentRenewal.new
          enrollment_renewal.enrollment = enrollment_assisted
          enrollment_renewal.assisted = true
          enrollment_renewal.aptc_values = {applied_percentage: 87,
                                            applied_aptc: 150,
                                            csr_amt: 100,
                                            max_aptc: 200}
          enrollment_renewal.renewal_coverage_start = renewal_benefit_coverage_period.start_on
          enrollment_renewal
        end

        before do
          hbx_profile.benefit_sponsorship.benefit_coverage_periods.each do |bcp|
            slcsp_id = if bcp.start_on.year == renewal_csr_87_product.application_period.min.year
                         renewal_csr_87_product.id
                       else
                         active_csr_87_product.id
                       end
            bcp.update_attributes!(slcsp_id: slcsp_id)
          end
          hbx_profile.reload
          family_assisted.active_household.reload
          update_age_off_excluded(family_assisted, false)
          allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate) {|_id, _start, age| age * 1.0}
        end

        it "should append APTC values" do
          enr = subject.clone_enrollment
          enr.save!
          expect(enr.kind).to eq subject.enrollment.kind
          renewel_enrollment = subject.assisted_enrollment(enr)
          #BigDecimal needed to round down
          expect(renewel_enrollment.applied_aptc_amount.to_f).to eq((BigDecimal((renewel_enrollment.total_premium * renewel_enrollment.product.ehb).to_s).round(2, BigDecimal::ROUND_DOWN)).round(2))
        end

        it "should append APTC values" do
          enr = subject.clone_enrollment
          enr.save!
          expect(subject.can_renew_assisted_product?(enr)).to eq true
        end

        it 'should create and assign new enrollment member objects to new enrollment' do
          new_enr = subject.clone_enrollment
          new_enr.save!
          expect(new_enr.subscriber.id).not_to eq(enrollment_assisted.subscriber.id)
        end
      end
    end
  end

  def create_eligibility_determination(family, yearly_expected_contribution, tax_household)
    determination = family.create_eligibility_determination(effective_date: TimeKeeper.date_of_record.beginning_of_year)
    determination.grants.create(
      key: "AdvancePremiumAdjustmentGrant",
      value: yearly_expected_contribution,
      start_on: TimeKeeper.date_of_record.beginning_of_year,
      end_on: TimeKeeper.date_of_record.end_of_year,
      assistance_year: TimeKeeper.date_of_record.year,
      member_ids: family.family_members.map(&:id).map(&:to_s),
      tax_household_id: tax_household.id
    )

    determination.grants.create(
      key: "AdvancePremiumAdjustmentGrant",
      value: yearly_expected_contribution,
      start_on: TimeKeeper.date_of_record.beginning_of_year.next_year,
      end_on: TimeKeeper.date_of_record.end_of_year.next_year,
      assistance_year: TimeKeeper.date_of_record.year + 1,
      member_ids: family.family_members.map(&:id).map(&:to_s),
      tax_household_id: tax_household.id
    )

    determination
  end

  def update_age_off_excluded(fam, true_or_false)
    fam.family_members.map(&:person).each do |per|
      per.update_attributes!(age_off_excluded: true_or_false)
    end
  end
end
