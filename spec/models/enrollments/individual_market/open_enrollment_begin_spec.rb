# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/spec/shared_contexts/enrollment.rb"

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  RSpec.describe Enrollments::IndividualMarket::OpenEnrollmentBegin, type: :model do
    include FloatHelper

    before do
      DatabaseCleaner.clean
    end

    let(:hbx_profile) { FactoryBot.create(:hbx_profile, :current_oe_period_with_past_coverage_periods) }

    context "Given a database of Families" do

      let!(:family) { FactoryBot.create(:individual_market_family) }
      let(:household) {FactoryBot.create(:household, family: family)}
      let!(:enrollment) {
                          FactoryBot.create(
                            :hbx_enrollment,
                            family: family,
                            household: household,
                            hbx_enrollment_members: [hbx_enrollment_member],
                            is_active: true,
                            aasm_state: 'coverage_enrolled',
                            changing: false,
                            effective_on: start_on,
                            coverage_kind: "health",
                            applied_aptc_amount: 10,
                            enrollment_kind: "open_enrollment",
                            kind: "individual",
                            submitted_at: start_on.prev_month,
                            product_id: product.id
                            )
                          }
      let(:hbx_enrollment_member) { FactoryBot.build(:hbx_enrollment_member, applicant_id: family.primary_family_member.id, is_subscriber: true, eligibility_date: TimeKeeper.date_of_record.beginning_of_year)}
      let!(:update_family) {family.active_household.hbx_enrollments << [enrollment]}
      let(:hbx_profile)               { FactoryBot.create(:hbx_profile) }
      let(:benefit_sponsorship)       { hbx_profile.benefit_sponsorship }
      let(:title)                     { "My new enrollment period" }
      let(:service_market)            { "individual" }
      let(:start_on)                  { TimeKeeper.date_of_record.beginning_of_year }
      let(:end_on)                    { TimeKeeper.date_of_record.end_of_year }
      let(:open_enrollment_start_on)  { TimeKeeper.date_of_record.beginning_of_year - 2.months }
      let(:open_enrollment_end_on)    { TimeKeeper.date_of_record.beginning_of_year.end_of_month }

      let!(:valid_params){
          {
            title: title,
            benefit_sponsorship: benefit_sponsorship,
            service_market: service_market,
            start_on: start_on,
            end_on: end_on,
            open_enrollment_start_on: open_enrollment_start_on,
            open_enrollment_end_on: open_enrollment_end_on
          }
        }

      let(:params)                  { valid_params }
      let!(:benefit_coverage_period) { BenefitCoveragePeriod.new(**params) }

      let(:active_individual_health_product)       { FactoryBot.create(:active_individual_health_product) }
      let(:active_shop_health_product)             { FactoryBot.create(:active_shop_health_product) }
      let(:active_individual_dental_product)       { FactoryBot.create(:active_individual_dental_product) }
      let(:active_individual_catastophic_product)  { FactoryBot.create(:active_individual_catastophic_product) }
      let(:active_csr_87_product)                  { FactoryBot.create(:active_csr_87_product) }
      let(:active_csr_00_product)                  { FactoryBot.create(:active_csr_00_product) }

      let(:renewal_individual_health_product)       { FactoryBot.create(:renewal_individual_health_product) }
      let(:renewal_shop_health_product)             { FactoryBot.create(:renewal_shop_health_product) }
      let(:renewal_individual_dental_product)       { FactoryBot.create(:renewal_individual_dental_product) }
      let(:renewal_individual_catastophic_product)  { FactoryBot.create(:renewal_individual_catastophic_product) }
      let(:renewal_csr_87_product) do
        FactoryBot.create(:renewal_csr_87_product).tap do |product|
          product.hios_base_id = product.hios_id.split("-").first
        end
      end
      let(:renewal_csr_00_product) do
        FactoryBot.create(:renewal_csr_00_product).tap do |product|
          product.hios_base_id = product.hios_id.split("-").first
        end
      end
      let!(:product) { FactoryBot.create(:active_ivl_gold_health_product, hios_id: "11111111122302-01", csr_variant_id: "01")}
      let!(:subject) {Enrollments::IndividualMarket::OpenEnrollmentBegin.new}

      it "the collection should include ten or more Families" do
        # expect(Family.all.size).to be >= 10
      end

      it "at least one Family with both active Individual Market Health and Dental product Enrollments"
      it "at least one Family with an active 'Individual Market Health product Enrollment only'"
      it "at least one Family with an active 'Assisted Individual Market Health product Enrollment only'"
      it "at least one Family with an active 'Individual Market Catastrophic product Enrollment only'"
      it "at least one Family with two active Individual Market Health product Enrollments, one which is responsible person"
      it "at least one Family with active Individual and SHOP Market Health product Enrollments"
      it "at least one Family with active Individual Market Dental and SHOP Market Health product Enrollments"
      it "at least one Family with a terminated 'Individual Market Health product Enrollment only'"
      it "at least one Family with a terminated 'Individual Market Dental product Enrollment only'"
      it "at least one Family with a future terminated 'Individual Market Health product Enrollment only'"
      it "at least one Family with a future terminated 'Individual Market Dental-only product Enrollment'"


      context "and only Families eligible for enrollment auto renewal processing are selected from database" do

        it "the set should include Families with both active Individual Market Health and Dental product Enrollments"
        it "the set should include Families with an active 'Individual Market Health product Enrollment only'"
        it "the set should include Families with active Individual and SHOP Market Health product Enrollments"
        it "the set should include Families with active Individual Market Dental and SHOP Market Health product Enrollments"

        it "the set should not include Families with a terminated 'Individual Market Health product Enrollment only'"
        it "the set should not include Families with a terminated 'Individual Market Dental product Enrollment only'"
        it "the set should not include Families a future terminated 'Individual Market Health product Enrollment only'"
        it "the set should not include Families a future terminated Individual Market Dental-only product Enrollment"


        context "and the Family with both active Individual Market Health and Dental product Enrollments is renewed" do
          it "should create a new Health enrollment"
          it "the new enrollment's health product should be valid for the upcoming calendar year"
          it "the new enrollment's effective date should be Jan 1 of next calendar year"
          it "the new enrollment should include all the enrollees from the current product year"
          it "the new enrollment should successfully calculate premium"

          it "should create a new Dental product enrollment"
          it "the new enrollment's dental product should be valid for the upcoming calendar year"
          it "the new enrollment's effective date should be Jan 1 of next calendar year"
          it "the new enrollment should include all the enrollees from the current product year"
          it "the new enrollment should have a calculatable premium"

          context "and one child dependent is over age 26 on Jan 1" do
            it "the child should be member of the extended_family_coverage_household"
            it "the child should not be member of the immediate_family_coverage_household"
            it "the child should not be included in the new health enrollment group"
            it "the child should not be included in the new dental enrollment group"
          end

          context "and one child dependent is over age 26 Jan 1 and disabled" do
            it "the child should not be member of the extended_family_coverage_household"
            it "the child should be member of the immediate_family_coverage_household"
            it "the child should be included in the new health enrollment group"
            it "the child should be included in the new dental enrollment group"
          end
        end

        context "and the Family with an active 'Assisted Individual Market Health product Enrollment only' is renewed" do

          context "and a financial eligibility determination is found" do
            context "and the determination end date is earlier than Jan 1 of the next calendar year" do
              it "the renewed enrollment should have $0 APTC for the new product year"

              context "and the renewed enrollment is a silver product" do
                it "the renewed product should not have a CSR variant"
              end
            end

            context "and the financial assistance redetermination has no end date" do
              it "the renewed enrollment should have the same APTC percentage as the current enrollment"

              context "and the renewed enrollment is a silver product" do
                it "the renewed product should not have the CSR variant from the financial redetermination"
              end
            end
          end
        end

        context "and the Family with an active 'Individual Market Catastrophic product Enrollment only' is renewed" do

          context "and none of the enrollment members are over age 30 on Jan 1" do
            it "the new enrollment should have a comparable Catastrophic product"
          end

          context "and at least one of the enrollment members are over age 30 on Jan 1" do
            it "should renew enrollment into a mapped Bronze product??"
          end
        end

        context "and the Family with two active Individual Market Health product Enrollments, one which is responsible person is renewed" do
          it "should produce a new standard enrollment"
          it "should produce a new responsible person enrollment"
        end

        context "and the Family with active Individual and SHOP Market Health product Enrollments" do
          it "should produce a new Individual health enrollment"
          it "should not produce a new SHOP health enrollment"
        end

        context "and the Family with active Individual Market Dental and SHOP Market Health product Enrollments" do
          it "should produce a new Individual dental enrollment"
          it "should not produce a new SHOP health enrollment"
        end

        it "for can_renew_coverage?" do
          value = enrollment.can_renew_coverage?(benefit_coverage_period.start_on)
          expect(value).to eq false
        end
      end
    end

    context "Today is 30 days prior to the first day of the Annual Open Enrollment period for the HBX Individual Market" do
      it "should generate and transmit renewal notices"
    end

    context "Today is the first day of the Annual Open Enrollment period for the HBX Individual Market" do
      context "and health and dental products and rates for the new calendar year are loaded" do
        context "and comparable product mapping from this calendar year to the next calendar year is present" do
          context "and Assisted QHP Families have finanancial eligibility redetermined for the next calendar year" do
          end
        end
      end
    end

    describe "To test passive renewals with only ivl health products" do
      include_context "setup families enrollments"

      before :each do
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(false)
      end

      context "Given a database of Families" do
        it "at least one Family with an active 'Individual Market Health product Enrollment only'" do
          expect(family_unassisted.active_household.hbx_enrollments.first.kind).to eq "individual"
        end

        it "at least one Family with an active 'Assisted Individual Market Health product Enrollment only'" do
          expect(family_assisted.active_household.hbx_enrollments.first.applied_aptc_amount).not_to eq 0
        end
      end

      describe ".kollection" do
        subject { Enrollments::IndividualMarket::OpenEnrollmentBegin.new }
        let!(:coverall_enrollment) do
          FactoryBot.create(:hbx_enrollment, :individual_unassisted, :with_enrollment_members,
                            family: family_unassisted,
                            kind: "coverall",
                            household: family_unassisted.active_household,
                            enrollment_members: [family_unassisted.family_members.first],
                            product: active_individual_health_product, effective_on: current_calender_date)
        end
        # BenefitCoveragePeriod will span for a year.
        let(:coverage_period) do
          double(
            "BenefitCoveragePeriod",
            start_on: current_calender_date.beginning_of_year,
            end_on: current_calender_date.end_of_year
          )
        end

        it "pull enrollments for both IVL and coverall" do
          query = subject.kollection(["health"], coverage_period)
          expect(family_unassisted.active_household.hbx_enrollments.where(query).count).to eq 2
        end
      end
    end

    describe 'when async processing is enabled' do
      include_context "setup families enrollments"

      before :each do
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(true)
      end

      let(:subject) { Enrollments::IndividualMarket::OpenEnrollmentBegin.new }

      it 'should invoke an event' do
        expect(subject).to receive(:event).exactly(2).times.and_call_original
        subject.process_renewals
      end

      context '#records' do
        context 'when osse disabled' do
          before do
            allow_any_instance_of(BenefitCoveragePeriod).to receive(:eligibility_on).and_return false
          end

          it 'should return family collection' do
            expect(subject.records.first.class).to eq Family
          end
        end

        context 'when osse enabled' do
          before do
            allow_any_instance_of(BenefitCoveragePeriod).to receive(:eligibility_on).and_return true
          end

          it 'should return family collection' do
            expect(subject.records.first.class).to eq Family
          end
        end
      end
    end

    describe '#osse_enabled' do
      it 'returns boolean for osse_enabled' do
        hbx_profile
        expect(subject.osse_enabled).to be_a(FalseClass)
      end
    end

    describe '.new' do
      it 'creates logger' do
        subject

        expect(
          File.exist?(
            "#{Rails.root}/log/ivl_open_enrollment_begin_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.log"
          )
        ).to be_truthy
      end
    end

    after :all do
      file_path = "#{Rails.root}/log/ivl_open_enrollment_begin_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.log"
      FileUtils.rm_rf(file_path) if File.file?(file_path)
    end
  end
end

private

def invoke_oe_script
  oe_begin = Enrollments::IndividualMarket::OpenEnrollmentBegin.new
  oe_begin.process_renewals
end
