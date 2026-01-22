module Hyrax
  module Listeners
    class FileListener
      ## TODO move all this to listeners/hyrax_listener.rb

      # Called when 'file.characterized' event is published
      # Waits for all files to be characterized before triggering derivative creation
      #
      # @param [Dry::Events::Event] event
      # @return [void]
      def on_file_characterized(event)
        file_set = event[:file_set]

        work = Hyrax.custom_queries.find_parent_work(resource: file_set)

        return unless all_files_characterized?(work)

        ValkyrieCreateDerivativesJob.perform_later(work.id.to_s)
      end

      ##
      # Called when 'file.uploaded' event is published
      # @param [Dry::Events::Event] event
      # @return [void]
      def on_file_uploaded(event)
        return if event.payload[:skip_derivatives] || !event[:metadata]&.original_file?

        ValkyrieCharacterizationJob.perform_later(event[:metadata].id.to_s)
      end

      private

      ##
      # Check if all file_sets for a work have been characterized
      # @param [Hyrax::Work] work
      # @return [Boolean]
      def all_files_characterized?(work)
        child_ids = work.member_ids
        child_works = child_ids.map { |id| Hyrax.query_service.find_by(id: id) }

        child_works_metadata =
          child_works.map do |cw|
            cw&.file_ids&.first&.then do |file_id|
              Hyrax.custom_queries.find_file_metadata_by(id: file_id)
            end
          end

        child_works_metadata.any?(&:nil?) ? false : true
      end
    end
  end
end
