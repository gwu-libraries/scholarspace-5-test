module Hyrax
    module DownloadsControllerDecorator
        include StringNormalization
        include Constants::MimeTypeConstants

        def show
            return show_valkyrie if Hyrax.config.use_valkyrie?

            show_active_fedora
        end

        def file_set_parent(file_set_id)
            file_set = if wings_metadata_adapter? && Hyrax.metadata_adapter.is_a?(Wings::Valkyrie::MetadataAdapter)
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
        rescue Ldp::HttpError => error
            solr_parent = solr_parent_for_file_set(file_set_id)
            return @parent = solr_parent if solr_parent.present?

            raise error
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

            file = derivative_cache_lookup(file_metadata)
            file ||= Valkyrie::StorageAdapter.find_by(id: file_metadata.file_identifier)

            file_for_range_and_headers = file.respond_to?(:stream) ? file.stream : file
            file_stream = file.respond_to?(:stream) ? file.stream : file

            prepare_file_headers_valkyrie(metadata: file_metadata, file: file_for_range_and_headers)

            if request.headers['Range']
                if request.head?
                    prepare_range_headers_valkyrie(file: file_for_range_and_headers)
                    head status
                else
                    send_data send_range_valkyrie(file: file_for_range_and_headers), data_options(file_metadata)
                end
            elsif request.head?
                head status
            else
                stream_body file_stream
            end
        end

        def derivative_download_options
            super.merge(disposition: 'attachment')
        end

        def disposition
            'attachment'
        end

        private

        def data_options(file_metadata)
            super.merge(type: download_response_mime_type(file_metadata))
        end

        def prepare_file_headers_valkyrie(metadata:, file:)
            super

            response_mime_type = download_response_mime_type(metadata)
            response.headers['Content-Type'] = response_mime_type
            self.content_type = response_mime_type
        end

        def derivative_cache_lookup(file_metadata)
            return nil unless is_pdf_or_hocr?(file_metadata)

            cached_stream = DerivativeCacheService.instance.fetch_stream(
                file_identifier: file_metadata.file_identifier,
                original_filename: file_metadata.original_filename
            )

            return nil unless cached_stream

            Rails.logger.info("Derivative cache hit for #{file_metadata.file_identifier}")
            cached_stream
        end

        def is_pdf_or_hocr?(file_metadata)
            mime_type = normalize_mime_type(file_metadata.respond_to?(:mime_type) ? file_metadata.mime_type : '')
            mime_type == PDF_MIME_TYPE || mime_type == HOCR_MIME_TYPE
        end

        def download_response_mime_type(file_metadata)
            return VTT_MIME_TYPE if vtt_download?(file_metadata)

            file_metadata.mime_type
        end

        def vtt_download?(file_metadata)
            return true if params[:format].to_s == 'vtt'

            mime_type = normalize_mime_type(file_metadata.respond_to?(:mime_type) ? file_metadata.mime_type : '')
            return true if mime_type == VTT_MIME_TYPE

            File.extname(file_metadata.original_filename.to_s).downcase == '.vtt'
        end

        def wings_metadata_adapter?
            !Hyrax.config.disable_wings &&
                defined?(Wings) &&
                defined?(Wings::Valkyrie) &&
                defined?(Wings::Valkyrie::MetadataAdapter)
        end

        def solr_parent_for_file_set(file_set_id)
            file_set_document = SolrDocument.find(file_set_id)
            source_file_set_id = source_file_set_id_for_download(file_set_document).presence || file_set_id
            response = Hyrax::SolrService.query_result(
                "member_ids_ssim:\"#{RSolr.solr_escape(source_file_set_id)}\"",
                fl: 'id',
                rows: 1
            )
            parent_id = response.dig('response', 'docs')&.first&.fetch('id', nil)
            return if parent_id.blank?

            SolrDocument.find(parent_id)
        rescue Blacklight::Exceptions::RecordNotFound, RSolr::Error::Http, StandardError => error
            Rails.logger.warn("Download parent Solr fallback failed for #{file_set_id}: #{error.class}: #{error.message}")
            nil
        end

        def source_file_set_id_for_download(file_set_document)
            related_url_values = Array(file_set_document['related_url_tesim']) + Array(file_set_document['related_url_ssim'])
            related_url_values
                .find { |value| value.to_s.start_with?('source_file_set_id:') }
                .to_s
                .delete_prefix('source_file_set_id:')
        end
    end
end
