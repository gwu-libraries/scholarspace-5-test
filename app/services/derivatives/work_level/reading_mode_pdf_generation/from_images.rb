# frozen_string_literal: true

require 'fileutils'
require 'open3'

module Derivatives
  module WorkLevel
    module ReadingModePdfGeneration
      class FromImages
        include Concerns::FileSetAttachable
        include FileOperations
        include PersistenceAdapter
        include StringNormalization

        def initialize(work)
          @work = work
        end

        def generate_to_cache(source_image_file_sets:)
          return if source_image_file_sets.empty?

          Dir.mktmpdir("images_to_pdf_generate_#{@work.id}_") do |dir|
            @working_dir = dir
            image_paths = copy_images_to_working_dir(source_image_file_sets)
            return if source_image_file_sets.size < 2

            join_images_to_pdf(image_paths)
            return nil unless @joined_pdf_path && File.exist?(@joined_pdf_path)

            cache_payload(source_file_set: source_image_file_sets.first, output_path: @joined_pdf_path)
          end
        rescue StandardError => e
          Rails.logger.error("ImagesToPdf PDF cache generation failed for work #{@work.id}: #{e.class} #{e.message}")
          raise
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          source_file_set = source_image_file_set_for(source_file_set_id)
          return unless source_file_set

          Dir.mktmpdir("images_to_pdf_persist_#{@work.id}_") do |dir|
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            return unless cached_io

            pdf_path = File.join(dir, cache_filename)
            File.open(pdf_path, 'wb') { |io| IO.copy_stream(cached_io, io) }

            joined_pdf_file_set = attach_pdf_to_work(pdf_path, source_file_set: source_file_set)
            joined_pdf_file_set&.id&.to_s
          ensure
            cached_io&.close
          end
        rescue StandardError => e
          Rails.logger.error("ImagesToPdf PDF persist failed for work #{@work.id}: #{e.class} #{e.message}")
          raise
        end

        def joined_pdf_filename
          Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
        end

        private

        def copy_images_to_working_dir(source_image_file_sets)
          ensure_directory_exists("#{@working_dir}/images")
          source_image_file_sets.each_with_index.map do |file_set, index|
            original_name = file_set.original_file.original_filename.to_s
            extension = File.extname(original_name).presence || '.jpg'
            image_path = "#{@working_dir}/images/#{format('%04d', index + 1)}#{extension}"
            copy_file_to_disk(file_set.original_file.file_identifier, image_path)
            image_path
          end
        end

        def source_image_file_set_for(source_file_set_id)
          Derivatives::FileSetLevel::TextExtraction::FromImages
            .new(@work)
            .source_image_file_sets
            .find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
        end

        def join_images_to_pdf(image_paths)
          ensure_directory_exists("#{@working_dir}/pdfs")
          @joined_pdf_path = "#{@working_dir}/pdfs/#{joined_pdf_filename}"
          return if image_paths.empty?

          page_pdf_paths = image_paths.each_with_index.map do |image_path, index|
            page_pdf = "#{@working_dir}/pdfs/page_#{format('%04d', index + 1)}.pdf"
            build_single_page_pdf_with_ocr(image_path: image_path, page_pdf: page_pdf, page_number: index + 1)
            page_pdf
          end

          concatenate_pdfs(page_pdf_paths, @joined_pdf_path)
        end

        def concatenate_pdfs(page_pdf_paths, output_path)
          cmd = [
            'gs',
            '-dBATCH',
            '-dNOPAUSE',
            '-sDEVICE=pdfwrite',
            '-dCompatibilityLevel=1.4',
            "-sOutputFile=#{output_path}",
            *page_pdf_paths
          ]
          _stdout, stderr, status = Open3.capture3(*cmd)
          unless status.success?
            Rails.logger.error(
              "ImagesToPdf gs concatenate failed work_id=#{@work&.id} " \
              "page_count=#{page_pdf_paths.size} " \
              "exit_status=#{status.exitstatus} stderr=#{stderr.strip.truncate(500)}"
            )
            raise "Unable to concatenate page PDFs (exit #{status.exitstatus}): #{stderr.strip.truncate(300)}"
          end
        end

        def build_single_page_pdf_with_ocr(image_path:, page_pdf:, page_number:)
          return if tesseract_page_pdf(image_path: image_path, page_pdf: page_pdf)

          cmd = [
            'magick',
            'convert',
            '-quality', '88',
            '-density', '150x150',
            image_path,
            page_pdf
          ]
          _stdout, stderr, status = Open3.capture3(*cmd)
          return if status.success?

          Rails.logger.error(
            "ImagesToPdf magick convert single-page failed work_id=#{@work&.id} " \
            "page=#{page_number} image=#{File.basename(image_path)} " \
            "exit_status=#{status.exitstatus} stderr=#{stderr.strip.truncate(500)}"
          )
          message = "Unable to convert image to PDF (page #{page_number}, exit #{status.exitstatus}): " \
                    "#{stderr.strip.truncate(300)}"
          raise message
        end

        def tesseract_page_pdf(image_path:, page_pdf:)
          output_base = page_pdf.sub(/\.pdf\z/, '')
          cmd = ['tesseract', image_path, output_base, 'pdf']
          _stdout, stderr, status = Open3.capture3(*cmd)
          generated_pdf = "#{output_base}.pdf"
          return false unless status.success? && File.exist?(generated_pdf)

          FileUtils.mv(generated_pdf, page_pdf) unless generated_pdf == page_pdf
          true
        rescue StandardError => e
          Rails.logger.warn(
            "ImagesToPdf tesseract single-page OCR PDF fallback work_id=#{@work&.id} " \
            "image=#{File.basename(image_path)} error=#{e.class}: #{e.message} " \
            "stderr=#{stderr.to_s.strip.truncate(200)}"
          )
          false
        end

        def attach_pdf_to_work(pdf_path, source_file_set:)
          return unless File.exist?(pdf_path) && depositor

          with_work_lock do
            @work = reload_work
            existing = joined_pdf_file_set
            return existing if existing

            File.open(pdf_path, 'rb') do |file_io|
              file_set = create_file_set_for_upload(
                file_path: pdf_path,
                user: depositor,
                io: file_io,
                source_file_set: source_file_set,
                skip_derivatives: true,
                derivative_type: Constants::DerivativeTypeConstants::DERIVATIVE_TYPE_PRESENTATION_VERSION
              )
              file_set.service_file = true
              file_set = save_and_index(file_set)

              @work.member_ids += [file_set.id]
              @work = Hyrax.persister.save(resource: @work)

              cache_derivative(
                file_path: pdf_path,
                file_set: file_set,
                derivative_type: Constants::DerivativeTypeConstants::DERIVATIVE_TYPE_PRESENTATION_VERSION
              )

              file_set
            end
          end
        end

        def joined_pdf_file_set
          @work.member_file_sets.find do |file_set|
            attached_name = file_set.original_file&.original_filename.to_s
            attached_title = file_set.title.to_a.join(' ')
            attached_name == Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME ||
              attached_title == Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
          end
        end

        def cache_payload(source_file_set:, output_path:)
          cache_filename = joined_pdf_filename
          cache_file_identifier = cache_file_identifier_for(filename: cache_filename)
          DerivativeCacheService.instance.store_derivative_from_path(
            file_identifier: cache_file_identifier,
            original_filename: cache_filename,
            source_path: output_path,
            derivative_type: Constants::DerivativeTypeConstants::DERIVATIVE_TYPE_PDF_DERIVATIVE
          )

          {
            source_file_set_id: source_file_set.id.to_s,
            cache_file_identifier: cache_file_identifier,
            cache_filename: cache_filename
          }
        end

        def cache_file_identifier_for(filename:)
          "derivatives:reading_mode_pdf:work:#{@work.id}:#{filename}"
        end

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end
      end
    end
  end
end