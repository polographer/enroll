# frozen_string_literal: true

RSpec.describe Operations::Households::DeactivateFinancialAssistanceEligibility, type: :model, dbclean: :after_each do
  let!(:family) {FactoryBot.create(:family, :with_primary_family_member)}
  let!(:family2) {FactoryBot.create(:family, :with_primary_family_member)}
  let!(:tax_household) { FactoryBot.create(:tax_household, household: family.active_household, effective_ending_on: nil, is_eligibility_determined: true) }
  let!(:eligibility_determination) {FactoryBot.create(:eligibility_determination, tax_household: tax_household, csr_percent_as_integer: 0)}

  let(:household) { family.active_household }
  let(:prospective_year_tax_household) { FactoryBot.create(:tax_household, :active_previous_year, household: household) }
  let(:retrospective_year_tax_household) { FactoryBot.create(:tax_household, :active_next_year, household: household) }

  let(:current_year_start) { TimeKeeper.date_of_record.beginning_of_year }

  describe '#call' do
    context 'with prospective and retrospective year tax household' do
      before do
        prospective_year_tax_household
        retrospective_year_tax_household
      end

      it 'deactivates current and future year active tax households' do
        expect(household.tax_households.active_tax_household.pluck(:id)).to include(prospective_year_tax_household.id, tax_household.id, retrospective_year_tax_household.id)
        subject.call(params: { deactivate_action_type: 'current_and_prospective',
                               family_id: family.id, date: current_year_start })
        household.reload
        expect(household.tax_households.active_tax_household.pluck(:id)).to include(prospective_year_tax_household.id)
        expect(household.tax_households.inactive.pluck(:id)).to include(tax_household.id, retrospective_year_tax_household.id)
      end
    end

    context 'with current_only deactivation type' do
      before do
        prospective_year_tax_household
        retrospective_year_tax_household
      end

      it 'deactivates current and future year active tax households' do
        expect(household.tax_households.active_tax_household.pluck(:id)).to include(prospective_year_tax_household.id, tax_household.id, retrospective_year_tax_household.id)
        subject.call(params: { deactivate_action_type: 'current_only',
                               family_id: family.id, date: current_year_start })
        household.reload
        expect(household.tax_households.active_tax_household.pluck(:id)).to include(prospective_year_tax_household.id)
        expect(household.tax_households.inactive.pluck(:id)).to include(tax_household.id)
      end
    end
  end

  it 'should be a container-ready operation' do
    expect(subject.respond_to?(:call)).to be_truthy
  end

  context 'invalid arguments' do
    it 'should return a failure' do
      result = subject.call(params: {deactivate_action_type: 'current_and_prospective',
                                     family_id: 'family_id', date: Date.new(2020, 1, 1)})
      expect(result.failure).to eq('family_id is expected in BSON format and date in required')
    end
  end

  # should not fail for UQHP cases too
  context 'no tax_households for uqhp family' do
    it 'should return success' do
      result = subject.call(params: {deactivate_action_type: 'current_and_prospective',
                                     family_id: family2.id, date: Date.new(2020, 1, 1)})
      expect(result.success).to eq 'No Active Tax Households to deactivate'
    end
  end

  context 'update tax households' do
    it 'should success for update' do
      result = subject.call(params: {deactivate_action_type: 'current_and_prospective',
                                     family_id: family.id, date: Date.new(tax_household.effective_starting_on.year, 1, 1)})
      expect(result.success).to eq "End dated all the Active Tax Households for given family with bson_id: #{family.id}"
    end
  end

  context 'success' do
    context 'input date falls before effective_starting_on' do
      before do
        tax_household.update_attributes(effective_starting_on: Date.new(2021,2,1))
        @result = subject.call(params: { deactivate_action_type: 'current_and_prospective',
                                         family_id: family.id, date: tax_household.effective_starting_on.prev_month })
      end

      it 'should end date thh' do
        expect(tax_household.reload.effective_ending_on).to eq(tax_household.effective_starting_on)
      end
    end
  end

  context 'when the family has no tax households for the effective year.' do
    before do
      tax_household.update_attributes(effective_starting_on: tax_household.effective_starting_on.prev_year)
    end

    it 'should return success' do
      result = subject.call(params: {deactivate_action_type: 'current_and_prospective',
                                     family_id: family.id, date: tax_household.effective_starting_on.next_year})
      expect(result.success).to eq 'No Active Tax Households to deactivate'
    end
  end
end
