# frozen_string_literal: true

require 'open3'

module ScholarspaceDerivativesServices
  class PdfToImagesDerivativesService
    include Concerns::FileSetAttachable
    include Concerns::HocrGeneratable
    include Concerns::OcrPdfGeneratable

    def initialize(work)
      @work = work
    end

    def call
      return if source_pdf_file_sets.empty?

      Dir.mktmpdir("pdf_to_images_#{@work.id}_") do |dir|
        @working_dir = dir
        Dir.mkdir("#{dir}/pdfs")
        Dir.mkdir("#{dir}/images")
        Dir.mkdir("#{dir}/hocr")
        source_pdf_file_sets.each do |pdf_file_set|
          if pdf_already_split?(pdf_file_set)
            image_paths = copy_existing_split_images_to_working_dir(pdf_file_set)
            attach_hocr_files_to_work(image_paths, source_file_set: pdf_file_set)
            next
          end

          source_pdf_path = copy_pdf_to_working_dir(pdf_file_set)
          ensure_searchable_rendering_pdf(source_pdf_path: source_pdf_path, source_file_set: pdf_file_set)
          split_paths = split_pdf_to_images(source_pdf_path, pdf_file_set)
          attach_hocr_files_to_work(split_paths, source_file_set: pdf_file_set)
          attach_images_to_work(split_paths, source_file_set: pdf_file_set)
        end
      end
    rescue StandardError => e
      Rails.logger.error("PdfToImagesDerivativesService failed for work #{@work.id}: #{e.class} #{e.message}")
      raise
    end

    def source_pdf_file_sets
      member_file_sets.select do |file_set|
        next false unless pdf_file_set?(file_set)

        !file_set.service_file
      end
    end

    def ensure_searchable_rendering_pdf(source_pdf_path:, source_file_set:)
      ocr_filename = ocr_rendering_filename_for(source_file_set)
      return if pdf_has_embedded_text?(source_pdf_path)
      return if file_set_attached_with_name?(ocr_filename)

      ocr_output_path = "#{@working_dir}/pdfs/#{ocr_filename}"
      return unless generate_ocr_rendering_pdf(source_pdf_path: source_pdf_path, ocr_output_path: ocr_output_path)

      attach_files_to_work([ocr_output_path], source_file_set: source_file_set)
    end

    def ocr_rendering_filename_for(source_file_set)
      source_filename = source_file_set.original_file&.original_filename.to_s
      stem = File.basename(source_filename, File.extname(source_filename))
      sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
      "#{sanitized.presence || 'source'}_OCR_RENDERING.pdf"
    end

    def copy_pdf_to_working_dir(pdf_file_set)
      source_name = File.basename(pdf_file_set.original_file.original_filename.to_s)
      source_pdf_path = "#{@working_dir}/pdfs/#{source_name}"
      io = Hyrax.storage_adapter.find_by(id: pdf_file_set.original_file.file_identifier)

      File.open(source_pdf_path, 'wb') do |destination_io|
        IO.copy_stream(io.stream, destination_io)
      end

      source_pdf_path
    end

    def split_pdf_to_images(pdf_path, pdf_file_set)
      stem = split_stem_for(pdf_file_set)
      output_pattern = "#{@working_dir}/images/#{stem}_page_%04d.jpg"
      cmd = [
        'magick',
        '-density', '150',
        pdf_path,
        '-quality', '90',
        output_pattern
      ]

      _stdout, _stderr, status = Open3.capture3(*cmd)
      return [] unless status.success?

      Dir.glob("#{@working_dir}/images/#{stem}_page_*.jpg").sort
    end

    def attach_images_to_work(image_paths, source_file_set:)
      attached_file_sets = attach_multiple_files_to_work(
        file_paths: image_paths,
        user: depositor,
        service_file: true,
        source_file_set: source_file_set
      )

      Hyrax.persister.save(resource: @work)
      Hyrax.index_adapter.save(resource: @work)
      attached_file_sets.each { |file_set| Hyrax.index_adapter.save(resource: file_set) }

      attached_file_sets
    end

    def attach_hocr_files_to_work(image_paths, source_file_set:)
      return if image_paths.empty?
      return unless depositor

      hocr_paths = generate_hocr_files(image_paths)
      hocr_paths_to_attach = hocr_paths.select do |hocr_path|
        File.exist?(hocr_path) && !file_set_attached_with_name?(File.basename(hocr_path))
      end
      return if hocr_paths_to_attach.empty?

      Rails.logger.info("PdfToImagesDerivativesService attaching #{hocr_paths_to_attach.size} hOCR file(s) for work #{@work.id}")
      attach_files_to_work(hocr_paths_to_attach, source_file_set: source_file_set)
    end

    def generate_hocr_files(image_paths)
      image_paths.map do |image_path|
        hocr_path = "#{@working_dir}/hocr/#{hocr_filename_for(image_path)}"
        generate_hocr_file(
          image_path: image_path,
          output_hocr_path: hocr_path,
          error_message: 'Unable to create hOCR from split PDF image'
        )
      end
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def hocr_filename_for(image_path)
      "#{File.basename(image_path, File.extname(image_path))}_HOCR.hocr"
    end

    def attach_files_to_work(file_paths, source_file_set:)
      attached_file_sets = attach_multiple_files_to_work(file_paths: file_paths, user: depositor, service_file: true, source_file_set: source_file_set)
      Hyrax.persister.save(resource: @work)
      Hyrax.index_adapter.save(resource: @work)
      attached_file_sets.each { |file_set| Hyrax.index_adapter.save(resource: file_set) }
    end

    def split_image_file_sets(pdf_file_set)
      stem = split_stem_for(pdf_file_set)
      member_file_sets.select do |file_set|
        filename = file_set.original_file&.original_filename.to_s
        file_set.original_file&.mime_type.to_s.start_with?('image/') && filename.start_with?("#{stem}_page_")
      end
    end

    def copy_existing_split_images_to_working_dir(pdf_file_set)
      split_image_file_sets(pdf_file_set).map do |image_file_set|
        filename = image_file_set.original_file.original_filename.to_s
        destination_path = "#{@working_dir}/images/#{filename}"
        io = Hyrax.storage_adapter.find_by(id: image_file_set.original_file.file_identifier)

        File.open(destination_path, 'wb') do |destination_io|
          IO.copy_stream(io.stream, destination_io)
        end

        destination_path
      end
    end

    def split_stem_for(pdf_file_set)
      filename = pdf_file_set.original_file.original_filename.to_s
      base = File.basename(filename, File.extname(filename)).gsub(/[^0-9A-Za-z.-]+/, '_')
      "#{base}_derivative"
    end

    def pdf_already_split?(pdf_file_set)
      stem = split_stem_for(pdf_file_set)
      member_file_sets.any? do |file_set|
        file_set.original_file&.original_filename.to_s.start_with?("#{stem}_page_")
      end
    end

    def pdf_file_set?(file_set)
      mime_type = file_set.original_file&.mime_type.to_s
      filename = file_set.original_file&.original_filename.to_s

      mime_type == 'application/pdf' || filename.downcase.end_with?('.pdf')
    end
  end
end