# frozen_string_literal: true

module ScholarspaceDerivativesServices
  module Concerns
    module FileSetAttachable
      include WorkLockable
      include DerivativeCacheable
      include PersistenceAdapter
      def file_set_attached_with_name?(filename)
        @work.member_file_sets.any? do |file_set|
          attached_name = file_set.original_file&.original_filename.to_s
          attached_title = file_set.title.to_a.join(' ')
          attached_name == filename || attached_title == filename
        end
      end

      def attach_single_file_to_work(file_path:, user:, service_file: false, source_file_set: nil)
        return nil unless File.exist?(file_path)

        file_io = File.open(file_path, 'rb')
        derivative_type = service_file ? derivative_type_for(file_path) : nil
        file_set = create_file_set_for_upload(
          file_path: file_path,
          user: user,
          io: file_io,
          source_file_set: source_file_set,
          skip_derivatives: service_file,
          derivative_type: derivative_type
        )
        attach_file_set_to_work(file_set)

        return file_set unless file_set && service_file

        file_set.service_file = true
        file_set = save_and_index(file_set)
        cache_derivative_file(
          file_path: file_path,
          file_set: file_set,
          derivative_type: derivative_type_for(file_path)
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

      def extract_attached_file_sets(payloads)
        Array.wrap(payloads).filter_map do |payload|
          payload.is_a?(Hash) ? payload[:file_set] : nil
        end
      end

      def create_file_set_for_upload(file_path:, user:, io:, source_file_set: nil, skip_derivatives: false, derivative_type: nil)
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
        file_set = apply_source_file_set_metadata(file_set: file_set, source_file_set: source_file_set, derivative_type: derivative_type)

        Hyrax::ValkyrieUpload.file(filename: filename, file_set: file_set, io: io, user: user, skip_derivatives: skip_derivatives)
        Hyrax.query_service.find_by(id: file_set.id)
      end

      def apply_source_file_set_permissions(file_set:, source_file_set:)
        return file_set unless source_file_set

        Hyrax::AccessControlList.copy_permissions(source: source_file_set, target: file_set)
        file_set.visibility = source_file_set.visibility if file_set.respond_to?(:visibility=) && source_file_set.respond_to?(:visibility)
        save_and_index(file_set)
      end

      def apply_source_file_set_metadata(file_set:, source_file_set:, derivative_type: nil)
        return file_set unless source_file_set || derivative_type.present?
        return file_set unless file_set.respond_to?(:related_url=)

        source_tag = source_file_set ? "source_file_set_id:#{source_file_set.id}" : nil
        derivative_tag = derivative_type.present? ? "derivative_type:#{derivative_type}" : nil
        existing_values = file_set.respond_to?(:related_url) ? Array(file_set.related_url).map(&:to_s) : []
        merged_values = (existing_values + [source_tag, derivative_tag].compact).uniq
        return file_set if merged_values == existing_values

        file_set.related_url = merged_values
        save_and_index(file_set)
      end

      def attach_file_set_to_work(file_set)
        with_work_lock do
          work = reload_work
          return unless work

          existing_member_ids = Array(work.member_ids).map(&:to_s)
          work.member_ids += [file_set.id] unless existing_member_ids.include?(file_set.id.to_s)
          work.representative_id = file_set.id if work.respond_to?(:representative_id) && work.representative_id.blank?
          work.thumbnail_id = file_set.id if work.respond_to?(:thumbnail_id) && work.thumbnail_id.blank?
          @work = Hyrax.persister.save(resource: work)
        end
      end

      def reload_work
        Hyrax.query_service.find_by(id: @work.id)
      end

      def derivative_type_for(file_path)
        extension = File.extname(file_path.to_s).delete('.').downcase
        case extension
        when 'hocr'
          'hocr'
        when 'vtt'
          'transcript'
        when 'jpg', 'jpeg', 'png', 'gif', 'tif', 'tiff', 'webp', 'jp2'
          'thumbnail'
        when 'pdf'
          'pdf_derivative'
        else
          extension.presence || 'derivative'
        end
      end

    end
  end
end
