# frozen_string_literal: true

require 'rails_helper'
require "#{FinancialAssistance::Engine.root}/spec/shared_examples/rrv/medicare/test_rrv_medicare_response"

RSpec.describe ::FinancialAssistance::Operations::Applications::Rrv::Medicare::AddRrvMedicareDetermination, dbclean: :after_each do
  before :all do
    DatabaseCleaner.clean
  end

  let!(:application) do
    FactoryBot.create(:financial_assistance_application, hbx_id: '200000126', aasm_state: "determined")
  end

  let!(:applicant) do
    FactoryBot.create(:financial_assistance_applicant,
                      eligibility_determination_id: nil,
                      person_hbx_id: '1629165429385938',
                      is_primary_applicant: true,
                      first_name: 'esi',
                      last_name: 'evidence',
                      ssn: "518124854",
                      dob: Date.new(1988, 11, 11),
                      application: application)
  end

  context 'success' do
    context 'FDSH RRV Medicare outstanding response' do
      include_context 'FDSH RRV Medicare sample response'

      before do
        @applicant = application.applicants.first
        @applicant.build_non_esi_evidence(key: :non_esi_mec, title: "NON ESI MEC")
        @applicant.save!
        @result = subject.call({payload: response_payload, applicant_identifier: '1629165429385938'})

        @application = ::FinancialAssistance::Application.by_hbx_id(response_payload[:hbx_id]).first.reload
        @app_entity = ::AcaEntities::MagiMedicaid::Operations::InitializeApplication.new.call(response_payload).success
        @applicant.reload
      end

      it 'should return success' do
        expect(@result).to be_success
      end

      it 'should update applicant verification' do
        expect(@applicant.non_esi_evidence.aasm_state).to eq "outstanding"
        expect(@result.success).to eq('Successfully updated Applicant with evidences and verifications')
      end

      it "should record request results" do
        expect(@applicant.non_esi_evidence.request_results.first.action).to eq "Hub Response"
      end
    end

    context 'FDSH RRV Medicare attested response' do
      include_context 'FDSH RRV Medicare sample response'

      before do
        @applicant = application.applicants.first
        @applicant.build_non_esi_evidence(key: :non_esi_mec, title: "NON ESI MEC")
        @applicant.save!
        @result = subject.call(payload: response_payload_2, applicant_identifier: '1629165429385938')

        @application = ::FinancialAssistance::Application.by_hbx_id(response_payload[:hbx_id]).first.reload
        @app_entity = ::AcaEntities::MagiMedicaid::Operations::InitializeApplication.new.call(response_payload).success
        @applicant.reload
      end

      it 'should return success' do
        expect(@result).to be_success
      end

      it 'should update applicant verification' do
        expect(@applicant.non_esi_evidence.aasm_state).to eq "attested"
        expect(@result.success).to eq('Successfully updated Applicant with evidences and verifications')
      end

      it "should record request results" do
        expect(@applicant.non_esi_evidence.request_results.first.action).to eq "Hub Response"
      end
    end
  end
end
