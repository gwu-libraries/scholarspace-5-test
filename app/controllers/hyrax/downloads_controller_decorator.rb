module Hyrax
    module DownloadsControllerDecorator
        def show
            return show_valkyrie if Hyrax.config.use_valkyrie?

            show_active_fedora
        end

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

        def load_file
            file_reference = params[:file]
            return default_file unless file_reference

            association = dereference_file(file_reference)
            association&.reader
        end

        def send_file_contents_valkyrie(file_set)
            mime_type = params[:mime_type]
            file_metadata = find_file_metadata(file_set: file_set, use: use, mime_type: mime_type)

            begin
                ::Valkyrie::StorageAdapter.adapter_for(id: file_metadata.file_identifier)
            rescue Valkyrie::StorageAdapter::AdapterNotFoundError
                return show_active_fedora
            end

            response.headers['Accept-Ranges'] = 'bytes'
            self.status = 200
            return unless stale?(last_modified: file_metadata.updated_at, template: false)

            # Try cache first for PDFs and hOCR files
            cached_stream = derivative_cache_lookup(file_metadata)
            if cached_stream
              file = cached_stream
            else
              file = Valkyrie::StorageAdapter.find_by(id: file_metadata.file_identifier)
            end

            prepare_file_headers_valkyrie(metadata: file_metadata, file: file)

            if request.headers['Range']
                if request.head?
                    prepare_range_headers_valkyrie(file: file)
                    head status
                else
                    send_data send_range_valkyrie(file: file), data_options(file_metadata)
                end
            elsif request.head?
                head status
            else
                stream_body file.stream
            end
        end

        def derivative_download_options
            super.merge(disposition: 'attachment')
        end

        def disposition
            'attachment'
        end

        private

        def derivative_cache_lookup(file_metadata)
            return nil unless is_pdf_or_hocr?(file_metadata)

            cached_stream = DerivativeCacheService.instance.fetch_stream(
                file_identifier: file_metadata.file_identifier,
                original_filename: file_metadata.original_filename
            )

            return nil unless cached_stream

            # Wrap stream so it has .stream method like Valkyrie file objects
            Struct.new(:stream).new(cached_stream)
        end

        def is_pdf_or_hocr?(file_metadata)
            return false if file_metadata.original_filename.blank?

            filename = file_metadata.original_filename.to_s.downcase
            filename.end_with?('.pdf', '.hocr')
        end
    end
end

Hyrax::DownloadsController.prepend Hyrax::DownloadsControllerDecorator
