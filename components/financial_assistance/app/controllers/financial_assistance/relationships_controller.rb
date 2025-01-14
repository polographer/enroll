# frozen_string_literal: true

module FinancialAssistance
  class RelationshipsController < FinancialAssistance::ApplicationController
    before_action :find_application
    before_action :set_cache_headers, only: [:index]

    layout 'financial_assistance_nav'

    def index
      authorize @application, :index?

      @matrix = @application.build_relationship_matrix
      @missing_relationships = @application.find_missing_relationships(@matrix)
      @all_relationships = @application.find_all_relationships(@matrix)
      @relationship_kinds = ::FinancialAssistance::Relationship::RELATIONSHIPS_UI
    end

    def create
      authorize @application, :create?

      applicant_id = params[:applicant_id]
      relative_id = params[:relative_id]
      predecessor = FinancialAssistance::Applicant.find(applicant_id)
      successor = FinancialAssistance::Applicant.find(relative_id)
      @application.add_relationship(predecessor, successor, params[:kind], true)
      @application.add_relationship(successor, predecessor, FinancialAssistance::Relationship::INVERSE_MAP[params[:kind]], true)
      @matrix = @application.build_relationship_matrix
      @missing_relationships = @application.find_missing_relationships(@matrix)
      @all_relationships = @application.find_all_relationships(@matrix)
      @relationship_kinds = ::FinancialAssistance::Relationship::RELATIONSHIPS_UI
      @people = nil

      respond_to do |format|
        format.html do
          redirect_to application_relationships_path, notice: 'Relationship was successfully updated.'
        end
        format.js
      end
    end
  end
end
