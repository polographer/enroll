# frozen_string_literal: true

require "rails_helper"

describe Forms::HealthcareForChildcareProgramForm do

  context '.load_eligibility' do
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: primary)}
    let!(:hbx_profile) {FactoryBot.create(:hbx_profile)}
    let!(:benefit_sponsorship) { FactoryBot.create(:benefit_sponsorship, :open_enrollment_coverage_period, hbx_profile: hbx_profile) }
    let!(:benefit_coverage_period) { hbx_profile.benefit_sponsorship.benefit_coverage_periods.first }
    let(:catalog_eligibility) do
      Operations::Eligible::CreateCatalogEligibility.new.call(
        {
          subject: benefit_coverage_period.to_global_id,
          eligibility_feature: "aca_ivl_osse_eligibility",
          effective_date: benefit_coverage_period.start_on.to_date,
          domain_model: "AcaEntities::BenefitSponsors::BenefitSponsorships::BenefitSponsorship"
        }
      )
    end

    let(:eligibility_params) do
      {
        evidence_key: :ivl_osse_evidence,
        evidence_value: true,
        effective_date: ::TimeKeeper.date_of_record
      }
    end

    before do
      allow(::EnrollRegistry).to receive(:feature?).and_return(true)
      allow(::EnrollRegistry).to receive(:feature_enabled?).and_return(true)
      TimeKeeper.set_date_of_record_unprotected!(Date.new(Date.today.year, 5, 1))
      catalog_eligibility
    end

    after do
      TimeKeeper.set_date_of_record_unprotected!(Date.today)
    end

    context 'with consumer role' do
      let(:primary) { FactoryBot.create(:person, :with_consumer_role) }
      let(:osse_eligibility) { build(:ivl_osse_eligibility, :with_admin_attested_evidence, evidence_state: :approved, is_eligible: false)}

      before do
        allow(EnrollRegistry[:aca_ivl_osse_effective_beginning_of_year].feature).to receive(:is_enabled).and_return(true)
        primary.consumer_role.create_or_term_eligibility(eligibility_params)
        primary.reload
      end

      it 'should return eligibility' do
        expect(subject.osse_eligibility).to be_blank
        expect(subject.role).to be_blank

        subject.load_eligibility(primary)
        expect(subject.osse_eligibility).to be_truthy
        expect(subject.role).to eq(primary.consumer_role)
      end

      it 'should set eligibility start date as beginning of year' do
        subject.load_eligibility(primary)
        expect(subject.osse_eligibility).to be_truthy
        osse_eligibility = subject.role.eligibilities.first
        expect(osse_eligibility.effective_on).to eq(TimeKeeper.date_of_record.beginning_of_year)
        expect(osse_eligibility.evidences.first.is_satisfied).to be_truthy
      end
    end

    context 'when both consumer and resident role present' do
      let(:primary) { FactoryBot.create(:person, :with_consumer_role, :with_resident_role) }
      let(:osse_eligibility) { build(:ivl_osse_eligibility, :with_admin_attested_evidence, evidence_state: :approved, is_eligible: false)}

      before do
        allow(EnrollRegistry[:aca_ivl_osse_effective_beginning_of_year].feature).to receive(:is_enabled).and_return(true)
        primary.resident_role.create_or_term_eligibility(eligibility_params)
        primary.reload
      end

      it 'should return eligibility with resident role' do
        expect(subject.osse_eligibility).to be_blank
        expect(subject.role).to be_blank

        subject.load_eligibility(primary)

        expect(subject.osse_eligibility).to be_truthy
        expect(subject.role).to eq(primary.resident_role)
      end

      it 'should set eligibility start date as beginning of year' do
        subject.load_eligibility(primary)
        expect(subject.osse_eligibility).to be_truthy
        osse_eligibility = subject.role.eligibilities.first
        expect(osse_eligibility.effective_on).to eq(TimeKeeper.date_of_record.beginning_of_year)
        expect(osse_eligibility.evidences.first.is_satisfied).to be_truthy
      end
    end
  end

  context '.build_forms_for' do
    let(:primary) { FactoryBot.create(:person, :with_consumer_role) }
    let(:spouse) { FactoryBot.create(:person, :with_consumer_role) }
    let(:child1) { FactoryBot.create(:person, :with_consumer_role) }

    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: primary)}
    let!(:family_member_spouse) { FactoryBot.create(:family_member, person: spouse, family: family)}
    let!(:family_member_child1) { FactoryBot.create(:family_member, person: child1, family: family)}

    it 'should build form objects for all active members' do
      forms = described_class.build_forms_for(family)
      expect(forms.keys.count).to eq family.active_family_members.count

      family.active_family_members.each do |fm|
        expect(forms.key?(fm.person)).to be_truthy
        expect(forms[fm.person]).to be_an_instance_of(described_class)
      end
    end
  end

  context '.submit_with' do
    let(:primary) { FactoryBot.create(:person, :with_consumer_role) }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: primary)}

    let(:params) do
      {
        person_id: primary.id,
        osse_eligibility: osse_eligibility
      }
    end

    let(:start_on) { ::TimeKeeper.date_of_record }

    before do
      allow(::EnrollRegistry).to receive(:feature?).and_return(true)
      allow(::EnrollRegistry).to receive(:feature_enabled?).and_return(true)
    end

    context 'when osse_eligibility selected YES' do
      let(:osse_eligibility) { 'true' }

      it 'should create osse eligibility' do
        expect(primary.consumer_role.osse_eligible?(start_on)).to be_falsey
        described_class.submit_with(params)

        primary.reload
        expect(primary.consumer_role.osse_eligible?(start_on)).to be_truthy
      end
    end

    context 'when osse_eligibility selected NO' do
      let(:osse_eligibility) { 'false' }

      before do
        primary.consumer_role.create_or_term_eligibility({
                                                           evidence_key: :ivl_osse_evidence,
                                                           evidence_value: true,
                                                           effective_date: ::TimeKeeper.date_of_record
                                                         })
        primary.reload
      end

      it 'should terminate osse eligibility' do
        expect(primary.consumer_role.osse_eligible?(start_on)).to be_truthy
        described_class.submit_with(params)
        expect(primary.consumer_role.reload.osse_eligible?(start_on)).to be_falsey
      end
    end

    context 'when both consumer and resident role present' do
      let(:primary) { FactoryBot.create(:person, :with_consumer_role, :with_resident_role) }
      let(:osse_eligibility) { 'true' }

      it 'should create eligibility with resident role' do
        expect(primary.consumer_role.osse_eligible?(start_on)).to be_falsey
        expect(primary.resident_role.osse_eligible?(start_on)).to be_falsey

        described_class.submit_with(params)

        primary.reload
        expect(primary.consumer_role.osse_eligible?(start_on)).to be_falsey
        expect(primary.resident_role.osse_eligible?(start_on)).to be_truthy
      end
    end
  end
end
