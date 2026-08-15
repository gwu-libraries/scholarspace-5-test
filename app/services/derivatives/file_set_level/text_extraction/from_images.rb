# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module TextExtraction
      # Entry point for extracting text from source images (hOCR + reading mode PDF flow).
      class FromImages
        include ::Constants::DerivativeFilenameConstants
        include ::Constants::DerivativeTypeConstants
        include ::Constants::DerivativeFilenameConstants
        include ::Constants::MimeTypeConstants
        include ::Constants::ThumbnailTagConstants

        include Concerns::FileSetAttachable
        include Concerns::TextExtraction::HocrGeneratable
        include Concerns::TextExtraction::HocrMergeable
        include FileOperations
        include PersistenceAdapter
        include StringNormalization

        def initialize(work)
          @work = work
        end

        def self.source_image_file_set_ids(work)
          new(work).source_image_file_sets.map { |file_set| file_set.id.to_s }
        end

        def generate_to_cache(source_file_set_id:)
          return unless depositor

          source_file_set = source_image_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
          return unless source_file_set

          Dir.mktmpdir("images_to_pdf_page_#{@work.id}_") do |dir|
            @working_dir = dir
            image_derivative = copy_single_image_to_working_dir(source_file_set)
            generate_hocr_files([image_derivative])

            hocr_path = image_derivative[:hocr_path]
            return nil unless hocr_path && File.exist?(hocr_path)

            cache_filename = File.basename(hocr_path)
            cache_file_identifier = cache_file_identifier_for(
              source_file_set_id: source_file_set.id,
              filename: cache_filename
            )

            DerivativeCacheService.instance.store_derivative_from_path(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename,
              source_path: hocr_path,
              derivative_type: DERIVATIVE_TYPE_HOCR
            )

            {
              source_file_set_id: source_file_set.id.to_s,
              cache_file_identifier: cache_file_identifier,
              cache_filename: cache_filename
            }
          end
        rescue StandardError => e
          Rails.logger.error(
            "ImagesToPdf page cache failed for work #{@work.id}, source #{source_file_set_id}: " \
            "#{e.class} #{e.message}"
          )
          raise
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          return unless depositor

          source_file_set = source_image_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
          return unless source_file_set
          return if file_set_attached_with_name?(cache_filename)

          Dir.mktmpdir("images_to_pdf_persist_#{@work.id}_") do |dir|
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            return unless cached_io

            hocr_path = File.join(dir, cache_filename)
            File.open(hocr_path, 'wb') { |io| IO.copy_stream(cached_io, io) }
            attach_file_to_work(hocr_path, source_file_set: source_file_set)
          ensure
            cached_io&.close
          end
        rescue StandardError => e
          Rails.logger.error(
            "ImagesToPdf persist failed for work #{@work.id}, source #{source_file_set_id}: " \
            "#{e.class} #{e.message}"
          )
          raise
        end

        def assemble_joined_hocr!(source_pdf_file_set_id: nil)
          return if source_image_file_sets.empty?

          Dir.mktmpdir("images_to_pdf_assemble_hocr_#{@work.id}_") do |dir|
            @working_dir = dir
            image_derivatives = copy_hocr_images_to_working_dir
            ensure_hocr_files(image_derivatives)
            return if source_image_file_sets.size < 2

            source_pdf_file_set = source_pdf_file_set_for(source_pdf_file_set_id)
            source_pdf_file_set ||= joined_pdf_file_set

            joined_hocr_file_set = attach_joined_hocr_to_work(
              image_derivatives,
              source_pdf_file_set: source_pdf_file_set
            )

            joined_hocr_file_set&.id&.to_s
          end
        rescue StandardError => e
          Rails.logger.error("ImagesToPdf hOCR assembly failed for work #{@work.id}: #{e.class} #{e.message}")
          raise
        end

        def source_image_file_sets
          @work.member_file_sets.select do |file_set|
            next false unless file_set.original_file&.mime_type.to_s.start_with?(IMAGE_MIME_PREFIX)

            !file_set.service_file
          end.sort_by do |file_set|
            normalize_filename(file_set.original_file&.original_filename)
          end
        end

        private

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end

        def copy_hocr_images_to_working_dir
          ensure_directory_exists("#{@working_dir}/images")
          ensure_directory_exists("#{@working_dir}/hocr")

          source_image_file_sets.each_with_index.map do |file_set, index|
            original_name = file_set.original_file.original_filename.to_s
            extension = File.extname(original_name).presence || '.jpg'
            image_path = "#{@working_dir}/images/#{format('%04d', index + 1)}#{extension}"
            copy_file_to_disk(file_set.original_file.file_identifier, image_path)

            {
              file_set: file_set,
              image_path: image_path,
              hocr_path: "#{@working_dir}/hocr/#{hocr_filename_for(file_set)}"
            }
          end
        end

        def copy_single_image_to_working_dir(source_file_set)
          ensure_directory_exists("#{@working_dir}/images")
          ensure_directory_exists("#{@working_dir}/hocr")

          original_name = source_file_set.original_file.original_filename.to_s
          extension = File.extname(original_name).presence || '.jpg'
          image_path = "#{@working_dir}/images/#{sanitized_component(source_file_set.id.to_s)}#{extension}"
          copy_file_to_disk(source_file_set.original_file.file_identifier, image_path)

          {
            file_set: source_file_set,
            image_path: image_path,
            hocr_path: "#{@working_dir}/hocr/#{hocr_filename_for(source_file_set)}"
          }
        end

        def generate_hocr_files(image_derivatives)
          ensure_directory_exists("#{@working_dir}/hocr")
          image_derivatives.each do |image_derivative|
            generate_hocr_file(
              image_path: image_derivative[:image_path],
              output_hocr_path: image_derivative[:hocr_path],
              error_message: 'Unable to create hOCR from image'
            )
          end
        end

        def ensure_hocr_files(image_derivatives)
          ensure_directory_exists("#{@working_dir}/hocr")

          image_derivatives.each do |image_derivative|
            hocr_path = image_derivative[:hocr_path]
            next if hocr_path.blank? || File.exist?(hocr_path)

            filename = File.basename(hocr_path)
            attached_hocr = find_service_file_set_by_filename(filename)
            file_identifier = attached_hocr&.original_file&.file_identifier

            if file_identifier.present?
              copy_file_to_disk(file_identifier, hocr_path)
              next if File.exist?(hocr_path)
            end

            generate_hocr_file(
              image_path: image_derivative[:image_path],
              output_hocr_path: hocr_path,
              error_message: 'Unable to create hOCR from image during finalize'
            )
          end
        end

        def attach_joined_hocr_to_work(image_derivatives, source_pdf_file_set: nil)
          joined_hocr_path = build_joined_hocr_file(image_derivatives)
          return unless joined_hocr_path && File.exist?(joined_hocr_path) && depositor

          filename = File.basename(joined_hocr_path)
          existing = find_service_file_set_by_filename(filename)
          if existing
            ensure_hocr_linked_to_source_pdf(existing, source_pdf_file_set)
            return existing
          end

          attach_file_to_work(
            joined_hocr_path,
            source_file_set: source_pdf_file_set || source_image_file_sets.first
          )
        end

        def ensure_hocr_linked_to_source_pdf(hocr_file_set, source_pdf_file_set)
          return unless hocr_file_set && source_pdf_file_set
          return unless hocr_file_set.respond_to?(:related_url=)

          source_tag = "#{SOURCE_FILE_SET_ID_PREFIX}#{source_pdf_file_set.id}"
          existing_values = hocr_file_set.respond_to?(:related_url) ? Array(hocr_file_set.related_url).map(&:to_s) : []
          return if existing_values.include?(source_tag)

          hocr_file_set.related_url = (existing_values + [source_tag]).uniq
          persisted = Hyrax.persister.save(resource: hocr_file_set)
          index_resources([persisted]) if persisted
        end

        def attach_page_hocr_to_work(image_derivatives)
          return unless depositor

          attached_count = 0
          image_derivatives.each do |image_derivative|
            hocr_path = image_derivative[:hocr_path]
            next unless hocr_path && File.exist?(hocr_path)

            filename = File.basename(hocr_path)
            next if file_set_attached_with_name?(filename)

            attach_file_to_work(hocr_path, source_file_set: image_derivative[:file_set])
            attached_count += 1
          end

          Rails.logger.info(
            "derivative_pipeline event=image_text_persist_batch_done work_id=#{@work.id} " \
            "attached_count=#{attached_count}"
          )
        end

        def attach_file_to_work(file_path, source_file_set: nil)
          file_set = attach_single_file_to_work(file_path: file_path,
                                                user: depositor,
                                                service_file: true,
                                                source_file_set: source_file_set)

          @work = save_and_index(@work)
          index_resources([file_set]) if file_set
          file_set
        end

        def hocr_filename_for(file_set)
          original_filename = file_set.original_file.original_filename.to_s
          title = preferred_title(file_set)

          title_component = sanitized_component(File.basename(title, File.extname(title)))
          source_component = sanitized_component(File.basename(original_filename, File.extname(original_filename)))
          stem = [title_component, source_component].reject(&:blank?).uniq.join('_')
          stem = 'image' if stem.blank?

          "#{stem}_HOCR.hocr"
        end

        def preferred_title(file_set)
          file_set.title.to_a.first.to_s
        end

        def sanitized_component(value)
          value.to_s.strip.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
        end

        def source_pdf_file_set_for(source_pdf_file_set_id)
          return nil if source_pdf_file_set_id.blank?

          @work.member_file_sets.find { |file_set| file_set.id.to_s == source_pdf_file_set_id.to_s }
        end

        def joined_pdf_file_set
          @work.member_file_sets.find do |file_set|
            attached_name = file_set.original_file&.original_filename.to_s
            attached_title = file_set.title.to_a.join(' ')
            attached_name == Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME ||
              attached_title == Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
          end
        end

        def find_service_file_set_by_filename(filename)
          return nil if filename.blank?
          return nil unless @work.respond_to?(:member_file_sets)

          @work.member_file_sets.find do |file_set|
            next false unless file_set.respond_to?(:service_file) && file_set.service_file

            attached_name = file_set.original_file&.original_filename.to_s
            attached_title = file_set.title.to_a.join(' ')
            attached_name == filename || attached_title == filename
          end
        end

        def build_joined_hocr_file(image_derivatives)
          hocr_paths = image_derivatives.map { |image_derivative| image_derivative[:hocr_path] }
          merge_hocr_files(hocr_paths)
        end

        def joined_hocr_filename
          READING_MODE_HOCR_FILENAME
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:reading_mode_pdf_generation:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end
      end
    end
  end
end
