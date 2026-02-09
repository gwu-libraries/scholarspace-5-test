Rails.application.config.to_prepare do
  module Hyrax
    module WorkUploadsHandlerDecorator

      private

      def make_file_set_and_ingest(file, file_set_params = {})
            file_set = @persister.save(resource: Hyrax::FileSet.new(file_set_args(file, file_set_params)))
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

            { file_set: file_set, user: file.user, job: ValkyrieIngestJob.new(file) }
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
