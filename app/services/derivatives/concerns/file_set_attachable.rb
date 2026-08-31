# frozen_string_literal: true

module Derivatives
  module Concerns
    module FileSetAttachable
      include ::Constants::DerivativeTypeConstants
      include ::Constants::FileExtensionConstants
      include ::Constants::ThumbnailTagConstants
      include WorkLockable
      include DerivativeCacheWriter
      include PersistenceAdapter

      def refresh_work!
        refreshed = reload_work
        @work = refreshed if refreshed
      rescue Valkyrie::Persistence::ObjectNotFoundError
        @work
      end

      def member_file_set_by_id(file_set_id)
        return nil if file_set_id.blank?
        return nil unless Array(@work.member_ids).map(&:to_s).include?(file_set_id.to_s)

        @work.find_member_file_set(file_set_id)
      end

      def member_solr_documents
        ids = Array(@work.member_ids).map(&:to_s)
        return [] if ids.empty?
        return @member_solr_documents_cache[:docs] if @member_solr_documents_cache &&
                                                      @member_solr_documents_cache[:ids] == ids
        response = Hyrax::SolrService.post(
          "{!terms f=id}#{ids.join(',')}",
          rows: ids.size,
          fl: 'id,service_file_bsi,related_url_tesim,title_tesim'
        )
        docs = response.dig('response', 'docs') || []
        @member_solr_documents_cache = { ids: ids, docs: docs }
        docs
      end

      def service_file_document_named(filename)
        return nil if filename.blank?

        member_solr_documents.find do |doc|
          doc['service_file_bsi'] && Array(doc['title_tesim']).include?(filename)
        end
      end

      # Derivatives are created with title == filename, so title_tesim is the
      # indexed stand-in for the (unindexed) original filename.
      def file_set_attached_with_name?(filename)
        return false if filename.blank?

        member_solr_documents.any? { |doc| Array(doc['title_tesim']).include?(filename) }
      end

      def find_service_file_set_by_filename(filename)
        doc = service_file_document_named(filename)
        return nil unless doc

        member_file_set_by_id(doc['id'])
      end

      def linked_derivative_file_set(source_file_set:, filename:, derivative_type:)
        doc = member_solr_documents.find do |candidate|
          next false unless candidate['service_file_bsi']
          next false unless Array(candidate['title_tesim']).include?(filename)

          related = Array(candidate['related_url_tesim'])
          next false unless related.include?("#{SOURCE_FILE_SET_ID_PREFIX}#{source_file_set.id}")

          related.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{derivative_type}")
        end
        return nil unless doc

        member_file_set_by_id(doc['id'])
      end

      def attach_single_file_to_work(file_path:, user:, service_file: false, source_file_set: nil,
                                     derivative_type_override: nil)
        return nil unless File.exist?(file_path)

        file_io = File.open(file_path, 'rb')
        derivative_type = if service_file
                            derivative_type_override.presence || derivative_type_for(file_path)
                          end
        file_set = create_file_set_for_upload(
          file_path: file_path,
          user: user,
          io: file_io,
          source_file_set: source_file_set,
          skip_derivatives: service_file,
          derivative_type: derivative_type
        )

        # Persist service-file classification before membership attach so retries
        # cannot leave derivative files visible as originals.
        if file_set && service_file
          file_set.service_file = true
          file_set = save_and_index(file_set)
        end

        attach_file_set_to_work(file_set)

        return file_set unless file_set && service_file

        cache_derivative(
          file_path: file_path,
          file_set: file_set,
          derivative_type: derivative_type
        )
        file_set
      ensure
        file_io&.close
      end

      def attach_multiple_files_to_work(file_paths:, user:, service_file: false, source_file_set: nil)
        return [] if file_paths.empty?

        file_paths.filter_map do |file_path|
          attach_single_file_to_work(
            file_path: file_path,
            user: user,
            service_file: service_file,
            source_file_set: source_file_set
          )
        end
      end

      def replace_file_set_file(file_set:, file_path:, user:)
        return unless file_set
        return unless File.exist?(file_path)
        return unless user

        File.open(file_path, 'rb') do |io|
          Hyrax::ValkyrieUpload.file(
            filename: File.basename(file_path),
            file_set: file_set,
            io: io,
            user: user,
            skip_derivatives: true
          )
        end

        refreshed_file_set = Hyrax.query_service.find_by(id: file_set.id)
        save_and_index(refreshed_file_set)
      end

      def extract_attached_file_sets(payloads)
        Array.wrap(payloads).filter_map do |payload|
          payload.is_a?(Hash) ? payload[:file_set] : nil
        end
      end

      def create_file_set_for_upload(file_path:, user:, io:, source_file_set: nil, skip_derivatives: false,
                                     derivative_type: nil)
        filename = File.basename(file_path)
        file_set = Hyrax.persister.save(
          resource: Hyrax.config.valkyrie_file_set_class.new(
            depositor: user.user_key,
            creator: [user.user_key],
            title: [filename],
            label: filename,
            date_uploaded: Time.current,
            date_modified: Time.current
          )
        )

        file_set = apply_source_file_set_permissions(file_set: file_set, source_file_set: source_file_set)
        file_set = apply_source_file_set_metadata(file_set: file_set, source_file_set: source_file_set,
                                                  derivative_type: derivative_type)

        Hyrax::ValkyrieUpload.file(filename: filename, file_set: file_set, io: io, user: user, skip_derivatives: true)
        Hyrax.query_service.find_by(id: file_set.id)
      end

      def apply_source_file_set_permissions(file_set:, source_file_set:)
        return file_set unless source_file_set

        Hyrax::AccessControlList.copy_permissions(source: source_file_set, target: file_set)
        if file_set.respond_to?(:visibility=) && source_file_set.respond_to?(:visibility)
          file_set.visibility = source_file_set.visibility
        end
        # Persist intermediate state without indexing; upload + final save handles index updates.
        file_set = Hyrax.persister.save(resource: file_set)
      end

      def apply_source_file_set_metadata(file_set:, source_file_set:, derivative_type: nil)
        return file_set unless source_file_set || derivative_type.present?
        return file_set unless file_set.respond_to?(:related_url=)

        if derivative_type.present? && source_file_set.nil?
          raise ArgumentError, "Missing source_file_set for derivative_type=#{derivative_type}"
        end

        source_tag = source_file_set ? "#{SOURCE_FILE_SET_ID_PREFIX}#{source_file_set.id}" : nil
        derivative_tag = derivative_type.present? ? "#{THUMBNAIL_DERIVATIVE_PREFIX}#{derivative_type}" : nil
        existing_values = file_set.respond_to?(:related_url) ? Array(file_set.related_url).map(&:to_s) : []
        merged_values = (existing_values + [source_tag, derivative_tag].compact).uniq
        return file_set if merged_values == existing_values

        file_set.related_url = merged_values
        # Persist intermediate state without indexing; upload + final save handles index updates.
        file_set = Hyrax.persister.save(resource: file_set)
      end

      def attach_file_set_to_work(file_set)
        return unless file_set

        with_work_lock do
          work = reload_work
          existing_member_ids = Array(work.member_ids).map(&:to_s)
          changed = false
          unless existing_member_ids.include?(file_set.id.to_s)
            work.member_ids += [file_set.id]
            work.representative_id = file_set.id if work.respond_to?(:representative_id) && work.representative_id.blank?
            work.thumbnail_id = file_set.id if work.respond_to?(:thumbnail_id) && work.thumbnail_id.blank?
            work = Hyrax.persister.save(resource: work)
            changed = true
          end

          @work = work
          schedule_work_reindex(work.id) if changed
        end
      end

      def reload_work
        Hyrax.query_service.find_by(id: @work.id)
      end

      def derivative_type_for(file_path)
        extension = File.extname(file_path.to_s).delete('.').downcase
        case extension
        when DERIVATIVE_TYPE_HOCR
          DERIVATIVE_TYPE_HOCR
        when 'vtt'
          DERIVATIVE_TYPE_TRANSCRIPT
        when *IMAGE_EXTENSIONS
          DERIVATIVE_TYPE_THUMBNAIL
        when 'pdf'
          DERIVATIVE_TYPE_PDF_DERIVATIVE
        else
          extension.presence || DERIVATIVE_TYPE_DEFAULT
        end
      end
    end
  end
end
