Rails.application.config.to_prepare do
  module Hyrax
    module WorkUploadsHandlerDecorator
      FILE_SET_CREATE_CONFLICT_RETRY_ATTEMPTS = 5

      def attach
           return true if Array.wrap(files).empty? # short circuit to avoid aquiring a lock we won't use

           acquire_lock_for(work.id) do
             event_payloads = files.each_with_object([]).with_index do |(file, arry), index|
               arry << make_file_set_and_ingest(file, @file_set_params[index] || {})
             end
             BulkraxImportLogger.info("method: attach, work: #{work.id}, work members before save: #{work.member_ids}")
             @persister.save(resource: work)
             BulkraxImportLogger.info("method: attach, work: #{work.id}, work members after save: #{Hyrax.query_service.find_by(id: work.id).member_ids}")
             Hyrax.publisher.publish('object.metadata.updated', object: work, user: files.first.user)
             event_payloads.each do |payload|
               payload.delete(:job).enqueue
               Hyrax.publisher.publish('file.set.attached', payload)
             end
           end
         end


      private

      def append_to_work(file_set)
          # Try to catch behavior where the second file set is being saved and overwriting the membership of the first
          if (file_set.title[0].ends_with? "2.pdf") && (work.member_ids.length != 1)
            puts work.id
            binding.pry
          end
          work.member_ids += [file_set.id]
          work.representative_id = file_set.id if work.respond_to?(:representative_id) && work.representative_id.blank?
          work.thumbnail_id = file_set.id if work.respond_to?(:thumbnail_id) && work.thumbnail_id.blank?
          BulkraxImportLogger.info("method: append_to_work, file_set: #{file_set.inspect}, work members: #{work.member_ids}")
      end

      def make_file_set_and_ingest(file, file_set_params = {})
        file_set = save_file_set_with_conflict_retry(file_set_args(file, file_set_params))
        Hyrax.publisher.publish('object.deposited', object: file_set, user: file.user)
        file.add_file_set!(file_set)

            # copy ACLs; should we also be propogating embargo/lease?
            Hyrax::AccessControlList.copy_permissions(source: target_permissions, target: file_set)

            # set visibility from params and save
            extra_params = file_set_extra_params(file)
            file_set = apply_file_set_visibility(file_set, extra_params) if extra_params[:visibility].present?
            if file_set.embargo
              Hyrax::EmbargoManager.apply_embargo_for!(resource: file_set)
            end
            file_set.permission_manager.acl.save if file_set.permission_manager.acl.pending_changes?
            file_set = Hyrax.persister.save(resource: file_set)
            append_to_work(file_set)

            Rails.logger.info(
              "valkyrie_ingest_pending uploaded_file_id=#{file.id} file_set_id=#{file_set.id} " \
              "work_id=#{work.id} filename=#{file.file}"
            )

        { file_set: file_set, user: file.user, job: ValkyrieIngestJob.new(file) }
      end

      def save_file_set_with_conflict_retry(attributes)
        attempts = 0

        begin
          @persister.save(resource: Hyrax::FileSet.new(attributes))
        rescue ::Ldp::Conflict
          attempts += 1
          raise if attempts >= FILE_SET_CREATE_CONFLICT_RETRY_ATTEMPTS

          sleep((attempts * 0.1) + rand(0.0..0.1))
          retry
        end
      end

      def file_set_extra_params(file)
        file_set_params&.find { |fs| (fs[:uploaded_file_id] == file.id.to_s) || (fs[:uploaded_files].map { |f_id| f_id.to_s}.include? file.id.to_s) } || {}
      end

      def apply_file_set_visibility(file_set, file_set_params)
        visibility = file_set_params[:visibility]
        case visibility
        when "embargo"
          embargo_params = file_set_params.slice(:visibility_after_embargo, :visibility_during_embargo, :embargo_release_date)
          embargo_params[:embargo_release_date] = DateTime.parse(embargo_params[:embargo_release_date])
          embargo = Hyrax::Embargo.new(embargo_params)
          file_set.embargo = Hyrax.persister.save(resource: embargo)
        when "restricted", "authenticated"
          file_set.visibility = visibility
        end
        file_set
      end

    end
  end
  Hyrax::WorkUploadsHandler.prepend Hyrax::WorkUploadsHandlerDecorator
end
