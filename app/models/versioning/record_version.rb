module Versioning
  class RecordVersion
    attr_reader :kind, :record, :timestamp

    def initialize(rv_record, rv_kind, rv_timestamp)
      @record = rv_record
      @kind = rv_kind
      @timestamp = rv_timestamp
    end

    def resolve_to_model
      case kind
      when :history_track
        found_record = record.class.find(record.id)
        found_record.history_tracker_to_record(timestamp)
      when :version
        record.reload
        record.versions.detect do |v|
          v.updated_at == timestamp
        end
      else
        record.reload
        record
      end
    end
  end
end