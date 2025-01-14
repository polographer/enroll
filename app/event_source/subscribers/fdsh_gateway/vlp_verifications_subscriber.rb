# frozen_string_literal: true

module Subscribers
  module FdshGateway
  # Subscriber will receive response payload from FDSH gateway
    class VlpVerificationsSubscriber
      include EventSource::Logging
      include ::EventSource::Subscriber[amqp: 'fdsh.eligibilities.vlp']

      subscribe(:on_initial_verification_complete) do |delivery_info, metadata, response|
        logger.info "Vlp::VlpVerificationsSubscriber: invoked on_initial_verification_complete with delivery_info: #{delivery_info.inspect}, response: #{response.inspect}"
        payload = JSON.parse(response, :symbolize_names => true)
        person_hbx_id = metadata.correlation_id

        verification_payload = { person_hbx_id: person_hbx_id, metadata: metadata, response: payload }

        result = Operations::Fdsh::Vlp::H92::InitialResponseProcessor.new.call(verification_payload)

        if result.success?
          logger.info "Vlp::VlpVerificationsSubscriber: on_initial_verification_complete acked with success: #{result.success}"
          Operations::Fdsh::Vlp::Rx142::CloseCase::RequestCloseCase.new.call(payload, person_hbx_id) if EnrollRegistry.feature_enabled?(:send_close_case_request)
        else
          errors = result.failure
          logger.info "Vlp::VlpVerificationsSubscriber: on_initial_verification_complete acked with failure, errors: #{errors}"
        end
        ack(delivery_info.delivery_tag)
      rescue StandardError => e
        ack(delivery_info.delivery_tag)
        logger.error "Vlp::VlpVerificationsSubscriber: on_initial_verification_complete error_message: #{e.message}, backtrace: #{e.backtrace}"
      end
    end
  end
end
