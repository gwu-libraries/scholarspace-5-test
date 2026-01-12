module Hyrax
    module DownloadsControllerDecorator

        def file_set_parent(file_set_id)
            file_set = if !Hyrax.config.disable_wings && Hyrax.metadata_adapter.is_a?(Wings::Valkyrie::MetadataAdapter)
                          Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: file_set_id, use_valkyrie: Hyrax.config.use_valkyrie?)
                      else
                          Hyrax.query_service.find_by(id: file_set_id)
                      end
            @parent ||=
                case file_set
                when Hyrax::Resource
                  Hyrax.query_service.find_parents(resource: file_set).first
                else
                  file_set.parent
                end
        end
    end
end
Hyrax::DownloadsController.prepend Hyrax::DownloadsControllerDecorator
