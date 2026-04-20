# frozen_string_literal: true

module ScholarspaceDerivativesServices
  module Concerns
    module FileSetAttachable
      include WorkLockable
      include DerivativeCacheable

    private

    def member_file_sets
      Array(@work.member_ids).filter_map { |id| find_member_file_set(id) }
    end

    def file_set_attached_with_name?(filename)
      member_file_sets.any? do |file_set|
        attached_name = file_set.original_file&.original_filename.to_s
        attached_title = file_set.title.to_a.join(' ')
        attached_name == filename || attached_title == filename
      end
    end

    def attach_single_file_to_work(file_path:, user:, service_file: false, source_file_set: nil)
      return nil unless File.exist?(file_path)

      file_io = File.open(file_path, 'rb')
      file_set = create_file_set_for_upload(file_path: file_path, user: user, io: file_io, source_file_set: source_file_set, skip_derivatives: service_file)
      attach_file_set_to_work(file_set)

      if file_set && service_file
        file_set.service_file = true
        file_set = Hyrax.persister.save(resource: file_set)
        Hyrax.index_adapter.save(resource: file_set)
        cache_derivative_file(
          file_path: file_path,
          file_set: file_set,
          derivative_type: derivative_type_for(file_path)
        )
      end
      file_set
    ensure
      file_io&.close
    end

    def attach_multiple_files_to_work(file_paths:, user:, service_file: false, source_file_set: nil)
      return [] if file_paths.empty?

      attached_pairs = file_paths.filter_map do |file_path|
        next unless File.exist?(file_path)

        file_io = File.open(file_path, 'rb')
        begin
          file_set = create_file_set_for_upload(file_path: file_path, user: user, io: file_io, source_file_set: source_file_set, skip_derivatives: service_file)
          attach_file_set_to_work(file_set)
          { file_set: file_set, file_path: file_path }
        ensure
          file_io.close
        end
      end

      file_sets = attached_pairs.map { |pair| pair[:file_set] }

      if service_file
        file_sets = attached_pairs.map do |pair|
          fs = pair[:file_set]
          fs.service_file = true
          fs = Hyrax.persister.save(resource: fs)
          cache_derivative_file(
            file_path: pair[:file_path],
            file_set: fs,
            derivative_type: derivative_type_for(pair[:file_path])
          )
          fs
        end
        file_sets.each do |fs|
          Hyrax.index_adapter.save(resource: fs)
        end
      end
      file_sets
    end

    def extract_attached_file_sets(payloads)
      Array.wrap(payloads).filter_map do |payload|
        payload.is_a?(Hash) ? payload[:file_set] : nil
      end
    end

    def create_file_set_for_upload(file_path:, user:, io:, source_file_set: nil, skip_derivatives: false)
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

      Hyrax::ValkyrieUpload.file(filename: filename, file_set: file_set, io: io, user: user, skip_derivatives: skip_derivatives)
      Hyrax.query_service.find_by(id: file_set.id)
    end

    def apply_source_file_set_permissions(file_set:, source_file_set:)
      return file_set unless source_file_set

      Hyrax::AccessControlList.copy_permissions(source: source_file_set, target: file_set)
      file_set.visibility = source_file_set.visibility if file_set.respond_to?(:visibility=) && source_file_set.respond_to?(:visibility)
      Hyrax.persister.save(resource: file_set)
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

    def find_member_file_set(id)
      Hyrax.query_service.find_by(id: id)
    end

    def reload_work
      Hyrax.query_service.find_by(id: @work.id)
    end

    def derivative_type_for(file_path)
      extension = File.extname(file_path.to_s).delete('.').downcase
      extension.presence || 'derivative'
    end

    end
  end
end
