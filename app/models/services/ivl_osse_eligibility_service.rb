# frozen_string_literal: true

module Services
  # service for ivl osse actions
  class IvlOsseEligibilityService

    attr_reader :person, :role, :args

    def initialize(params)
      @person = Person.find(params[:person_id])
      @role = fetch_role
      @args = params
    end

    def fetch_role
      if person.has_active_resident_role?
        person.resident_role
      elsif person.has_active_consumer_role?
        person.consumer_role
      end
    end

    def osse_eligibility_years_for_display
      ::BenefitCoveragePeriod.osse_eligibility_years_for_display.sort.reverse
    end

    def osse_status_by_year
      osse_eligibility_years_for_display.inject({}) do |data, year|
        data[year] = {}
        start_on = Date.new(year, 0o1, 0o1)

        eligibility = role.eligibility_for(:ivl_osse_eligibility, start_on)

        eligible_on = year == TimeKeeper.date_of_record.year ? TimeKeeper.date_of_record : start_on
        data[year][:is_eligible] = eligibility&.is_eligible_on?(eligible_on) || false
        next data unless eligibility.present?
        latest_eligibility_period = eligibility.evidences.first&.eligible_periods&.last
        data[year][:start_on] = latest_eligibility_period[:start_on]
        data[year][:end_on] = latest_eligibility_period[:end_on] || latest_eligibility_period[:start_on].end_of_year

        data
      end
    end

    def get_osse_term_date(published_on)
      if published_on.year == TimeKeeper.date_of_record.year
        TimeKeeper.date_of_record
      else
        published_on
      end
    end

    def update_osse_eligibilities_by_year
      eligibility_result = {}

      args[:osse].each do |year, osse_eligibility|
        effective_on = Date.new(year.to_i, 0o1, 0o1)
        eligibility_record = role.eligibility_for(:ivl_osse_eligibility, effective_on)
        eligible_on = (year.to_i == TimeKeeper.date_of_record.year) ? TimeKeeper.date_of_record : effective_on
        if eligibility_record&.is_eligible_on?(eligible_on) && osse_eligibility.to_s == 'false'
          term_date = get_osse_term_date(eligibility_record.published_on)
          eligibility_result[year] = create_or_term_osse_eligibility(role, osse_eligibility, term_date)
        elsif osse_eligibility.to_s == 'true'
          eligibility_result[year] = create_or_term_osse_eligibility(role, osse_eligibility, effective_on)
        end
      end

      eligibility_result.group_by { |_key, value| value }.transform_values { |items| items.map(&:first) }
    end

    def create_or_term_osse_eligibility(role, osse_eligibility, effective_on)
      result = ::Operations::IvlOsseEligibilities::CreateIvlOsseEligibility.new.call(
        {
          subject: role.to_global_id,
          evidence_key: :ivl_osse_evidence,
          evidence_value: osse_eligibility.to_s,
          effective_date: effective_on
        }
      )
      result.success? ? "Success" : "Failure"
    end
  end
end