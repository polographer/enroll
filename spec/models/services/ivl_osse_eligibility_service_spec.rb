# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::IvlOsseEligibilityService, type: :model, :dbclean => :after_each do
  let!(:hbx_profile) {FactoryBot.create(:hbx_profile)}
  let!(:benefit_sponsorship) { FactoryBot.create(:benefit_sponsorship, :open_enrollment_coverage_period, hbx_profile: hbx_profile) }
  let!(:benefit_coverage_period) { hbx_profile.benefit_sponsorship.benefit_coverage_periods.first }
  let!(:catalog_eligibility) do
    Operations::Eligible::CreateCatalogEligibility.new.call(
      {
        subject: benefit_coverage_period.to_global_id,
        eligibility_feature: "aca_ivl_osse_eligibility",
        effective_date: benefit_coverage_period.start_on.to_date,
        domain_model: "AcaEntities::BenefitSponsors::BenefitSponsorships::BenefitSponsorship"
      }
    )
  end
  let(:person) { FactoryBot.create(:person, :with_consumer_role)}
  let(:role) { person.consumer_role }
  let(:current_date) { TimeKeeper.date_of_record }

  let(:params) { { person_id: person.id, osse: { current_date.year.to_s => "true", current_date.last_year.year.to_s => "false" } } }

  subject { described_class.new(params) }

  describe "#osse_eligibility_years_for_display" do
    it "returns sorted and reversed osse eligibility years" do
      expect(subject.osse_eligibility_years_for_display).to eq(
        ::BenefitCoveragePeriod.osse_eligibility_years_for_display.sort.reverse
      )
    end
  end

  describe "#osse_status_by_year" do
    before do
      osse_eligibility_years = [current_date.year, current_date.last_year.year, current_date.next_year.year]
      allow(BenefitCoveragePeriod).to receive(:osse_eligibility_years_for_display).and_return osse_eligibility_years
      ::Operations::IvlOsseEligibilities::CreateIvlOsseEligibility.new.call(
        {
          subject: role.to_global_id,
          evidence_key: :ivl_osse_evidence,
          evidence_value: "true",
          effective_date: TimeKeeper.date_of_record.beginning_of_year
        }
      )
    end

    it "returns osse status by year" do
      result = subject.osse_status_by_year
      expect(result[current_date.last_year.year][:is_eligible]).to eq(false)
      expect(result[current_date.next_year.year][:is_eligible]).to eq(false)
      expect(result[current_date.year][:is_eligible]).to eq(true)
      expect(result[current_date.year][:start_on]).to eq(current_date.beginning_of_year)
      expect(result[current_date.year][:end_on]).to eq(current_date.end_of_year)
    end
  end

  describe "#get_osse_term_date" do
    it "returns term date based on published_on" do
      result = subject.get_osse_term_date(TimeKeeper.date_of_record.last_year)
      expect(result).to eq(TimeKeeper.date_of_record.last_year)

      result = subject.get_osse_term_date(TimeKeeper.date_of_record.beginning_of_year)
      expect(result).to eq(TimeKeeper.date_of_record)
    end
  end

  describe "#update_osse_eligibilities_by_year" do
    it "updates osse eligibilities by year" do
      allow(subject).to receive(:create_or_term_osse_eligibility).and_return("Success")

      result = subject.update_osse_eligibilities_by_year

      expect(result).to eq({ "Success" => [current_date.year.to_s]})
    end
  end

  describe "#create_or_term_osse_eligibility" do
    it "creates or terms osse eligibility" do
      allow(::Operations::IvlOsseEligibilities::CreateIvlOsseEligibility.new).to receive(:call).and_return(double("Result", success?: true))

      result = subject.create_or_term_osse_eligibility(role, "true", TimeKeeper.date_of_record.beginning_of_year)

      expect(result).to eq("Success")
    end

    it "returns Failure if operation fails" do
      result = subject.create_or_term_osse_eligibility(role, "true", Date.today.to_s)

      expect(result).to eq("Failure")
    end
  end
end