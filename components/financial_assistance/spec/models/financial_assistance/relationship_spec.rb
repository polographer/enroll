# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FinancialAssistance::Relationship, type: :model, dbclean: :after_each do
  let(:bson_id) { BSON::ObjectId.new }
  let!(:application) { FactoryBot.create(:application, family_id: bson_id) }
  let!(:applicant1) { FactoryBot.create(:applicant, application: application, family_member_id: bson_id, is_primary_applicant: true) }
  let!(:applicant2) { FactoryBot.create(:applicant, application: application, family_member_id: bson_id) }

  let(:valid_params) do
    { kind: relationship_kind,
      applicant_id: applicant1.id,
      relative_id: applicant2.id }
  end

  describe '.Constants' do
    let(:class_constants)  { described_class.constants }
    let(:ui_rel_kinds) do
      if EnrollRegistry.feature_enabled?(:mitc_relationships)
        [
          'spouse',
          'domestic_partner',
          'child',
          'parent',
          'sibling',
          'unrelated',
          'aunt_or_uncle',
          'nephew_or_niece',
          'grandchild',
          'grandparent',
          'father_or_mother_in_law',
          'daughter_or_son_in_law',
          'brother_or_sister_in_law',
          'cousin',
          'domestic_partners_child',
          'parents_domestic_partner'
        ]
      else
        ['spouse',
         'domestic_partner',
         'child',
         'parent',
         'sibling',
         'unrelated',
         'aunt_or_uncle',
         'nephew_or_niece',
         'grandchild',
         'grandparent']
      end
    end

    it 'should have relationships for UI display as a constant' do
      expect(class_constants.include?(:RELATIONSHIPS_UI)).to be_truthy
      expect(described_class::RELATIONSHIPS_UI).to eq(ui_rel_kinds)
    end
  end

  describe 'domestic_partners_child, parents_domestic_partner' do
    let!(:person2) { FactoryBot.create(:person) }
    let(:relationship_kind) { ['domestic_partners_child', 'parents_domestic_partner'].sample }

    context 'persistance' do
      it 'should behave based on config for mitc_relationships' do
        if EnrollRegistry.feature_enabled?(:mitc_relationships)
          expect do
            application.relationships.create!(valid_params)
          end.not_to raise_error
        else
          expect do
            application.relationships.create!(valid_params)
          end.to raise_error(Mongoid::Errors::Validations, /Validation of FinancialAssistance::Relationship failed/)
        end
      end
    end

    context 'constants' do
      context 'RELATIONSHIPS' do
        it 'should behave based on config for mitc_relationships' do
          if EnrollRegistry.feature_enabled?(:mitc_relationships)
            expect(described_class::RELATIONSHIPS).to include(relationship_kind)
          else
            expect(described_class::RELATIONSHIPS).not_to include(relationship_kind)
          end
        end
      end

      context 'RELATIONSHIPS_UI' do
        it 'should behave based on config for mitc_relationships' do
          if EnrollRegistry.feature_enabled?(:mitc_relationships)
            expect(described_class::RELATIONSHIPS_UI).to include(relationship_kind)
          else
            expect(described_class::RELATIONSHIPS_UI).not_to include(relationship_kind)
          end
        end
      end
    end
  end

  describe 'propagate_applicant' do
    before do
      allow(FinancialAssistance::Operations::Application::RelationshipHandler).to receive(:new).and_call_original
    end

    context 'application is in draft' do
      before do
        application.reload
        application.update_or_build_relationship(applicant1, applicant2, 'spouse')
      end

      it 'should trigger operation call as application is in draft state' do
        expect(FinancialAssistance::Operations::Application::RelationshipHandler).to have_received(:new)
      end
    end

    context 'application is not in draft' do
      before do
        application.update_attributes!(aasm_state: 'submitted')
        application.update_or_build_relationship(applicant1, applicant2, 'spouse')
      end

      it 'should not trigger operation call as application is in draft state' do
        expect(FinancialAssistance::Operations::Application::RelationshipHandler).to_not have_received(:new)
      end
    end
  end

  describe 'applicant/relative/propagate_applicant' do
    before do
      @second_application = FactoryBot.build(:application, family_id: bson_id)
      second_applicant1 = FactoryBot.build(:applicant, application: @second_application, family_member_id: bson_id, is_primary_applicant: true)
      second_applicant2 = FactoryBot.build(:applicant, application: @second_application, family_member_id: bson_id)
      @second_application.relationships.build({ applicant_id: second_applicant1.id, kind: 'spouse', relative_id: second_applicant2.id })
    end

    it 'should not raise NoMethodError' do
      expect{ @second_application.save! }.not_to raise_error(NoMethodError)
    end

    it 'should return applicant' do
      expect(@second_application.relationships.first.applicant).to be_a(::FinancialAssistance::Applicant)
    end

    it 'should return relative' do
      expect(@second_application.relationships.first.relative).to be_a(::FinancialAssistance::Applicant)
    end
  end

  describe '#valid_relationship_kind?' do
    let(:relationship) { application.relationships.build(applicant_id: BSON::ObjectId.new, kind: relation_kind, relative_id: BSON::ObjectId.new)}
    let(:relation_kind) { 'spouse' }

    context 'valid relationship_kind' do
      let(:relation_kind) { 'spouse' }
      it 'should return true' do
        expect(relationship.valid_relationship_kind?).to be_truthy
      end
    end

    context 'relationship_kind is invalid' do
      let(:relation_kind) { 'life_partner' }
      it 'should return false' do
        expect(relationship.valid_relationship_kind?).to be_falsey
      end
    end
  end
end
