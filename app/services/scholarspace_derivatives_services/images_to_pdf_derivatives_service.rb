# frozen_string_literal: true

require 'open3'

module ScholarspaceDerivativesServices
  class ImagesToPdfDerivativesService
    include Concerns::FileSetAttachable
    include Concerns::HocrGeneratable
    include Concerns::HocrMergeable

    def initialize(work)
      @work = work
    end

    def call
      return if source_image_file_sets.empty?

      Dir.mktmpdir("images_to_pdf_#{@work.id}_") do |dir|
        @working_dir = dir
        image_derivatives = copy_images_to_working_dir
        generate_hocr_files(image_derivatives)
        attach_page_hocr_to_work(image_derivatives)
        next if source_image_file_sets.size < 2

        join_images_to_pdf(image_derivatives.map { |image| image[:image_path] })
        attach_pdf_to_work(@joined_pdf_path)
        attach_joined_hocr_to_work(image_derivatives)
      end
    rescue StandardError => e
      Rails.logger.error("ImagesToPdfDerivativesService failed for work #{@work.id}: #{e.class} #{e.message}")
      raise
    end

    def source_image_file_sets
      member_file_sets.select do |file_set|
        next false unless file_set.original_file&.mime_type.to_s.start_with?('image/')

        !file_set.service_file
      end.sort_by do |file_set|
        file_set.original_file&.original_filename.to_s.downcase
      end
    end

    def copy_images_to_working_dir
      Dir.mkdir("#{@working_dir}/images")
      source_image_file_sets.each_with_index.map do |fs, i|
        io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
        original_name = fs.original_file.original_filename.to_s
        extension = File.extname(original_name).presence || '.jpg'
        image_path = "#{@working_dir}/images/#{format('%04d', i + 1)}#{extension}"
        destination_io = File.open(image_path, 'wb')

        IO.copy_stream(io.stream, destination_io)
        destination_io.close

        {
          file_set: fs,
          image_path: image_path,
          hocr_path: "#{@working_dir}/hocr/#{hocr_filename_for(fs)}"
        }
      end
    end

    def generate_hocr_files(image_derivatives)
      Dir.mkdir("#{@working_dir}/hocr")
      image_derivatives.each do |image_derivative|
        generate_hocr_file(
          image_path: image_derivative[:image_path],
          output_hocr_path: image_derivative[:hocr_path],
          error_message: 'Unable to create hOCR from image'
        )
      end
    end

    def join_images_to_pdf(image_paths)
      Dir.mkdir("#{@working_dir}/pdfs")
      @joined_pdf_path = "#{@working_dir}/pdfs/#{joined_pdf_filename}"
      return if image_paths.empty?

      cmd = ['magick', 'convert', *image_paths, @joined_pdf_path]

      _stdout, _stderr, status = Open3.capture3(*cmd)
      raise 'Unable to create joined PDF from images' unless status.success?
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def attach_pdf_to_work(pdf_path)
      return unless File.exist?(pdf_path) && depositor

      filename = joined_pdf_filename
      return joined_pdf_file_set if file_set_attached_with_name?(filename)

      attach_file_to_work(pdf_path, source_file_set: source_image_file_sets.first)
    end

    def attach_joined_hocr_to_work(image_derivatives)
      joined_hocr_path = build_joined_hocr_file(image_derivatives)
      return unless joined_hocr_path && File.exist?(joined_hocr_path) && depositor

      filename = File.basename(joined_hocr_path)
      return if file_set_attached_with_name?(filename)

      attach_file_to_work(joined_hocr_path, source_file_set: source_image_file_sets.first)
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

      Rails.logger.info("ImagesToPdfDerivativesService attached #{attached_count} per-image hOCR file(s) for work #{@work.id}")
    end

    def attach_file_to_work(file_path, source_file_set: nil)
      file_set = attach_single_file_to_work(file_path: file_path, user: depositor, service_file: true, source_file_set: source_file_set)

      Hyrax.persister.save(resource: @work)
      Hyrax.index_adapter.save(resource: @work)
      Hyrax.index_adapter.save(resource: file_set) if file_set
      file_set
    end

    def joined_pdf_filename
      'joined_images_pdf.pdf'
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

    def joined_pdf_file_set
      member_file_sets.find do |file_set|
        attached_name = file_set.original_file&.original_filename.to_s
        attached_title = file_set.title.to_a.join(' ')
        attached_name == joined_pdf_filename || attached_title == joined_pdf_filename
      end
    end

    def build_joined_hocr_file(image_derivatives)
      hocr_paths = image_derivatives.map { |image_derivative| image_derivative[:hocr_path] }
      merge_hocr_files(hocr_paths)
    end

    def joined_hocr_filename
      "#{File.basename(joined_pdf_filename, '.pdf')}_HOCR.hocr"
    end

  end
end
