# frozen_string_literal: true

module DerivativeServices
  module Archival
    class ArchivalTextDerivativesService
      def initialize(work)
        @work = work

        @working_dir = nil

        @pdf_working_dir = nil
        @pdf_working_path = nil

        @image_working_dir = nil
        @image_joined_pdf_path = nil
      end

      def create_derivatives
        prepare_working_dir

        if pdf_file_sets.present?
          copy_pdfs_to_working_dir
          ocr_pdf(@pdf_working_path, @pdf_working_path)
          attach_pdf_to_work(@pdf_working_path)
          # generate a thumbnail for the first page of the pdf
        elsif image_file_sets.present?
          copy_images_to_working_dir
          join_images_to_pdf
          ocr_pdf(@image_joined_pdf_path, @image_joined_pdf_path)
          attach_pdf_to_work(@image_joined_pdf_path)
          # generate a thumbnail for the first page of the pdf
        end

        cleanup_working_dir
      end

      private

      def prepare_working_dir
        dir_name = Time.now.to_i.to_s # just using timestamp for naming unique temp directory
        Dir.mkdir(Rails.root.join('tmp', dir_name))
        Dir.mkdir(Rails.root.join('tmp', dir_name, 'images'))
        Dir.mkdir(Rails.root.join('tmp', dir_name, 'pdfs'))
        @working_dir = Rails.root.join('tmp', dir_name)
        @image_working_dir = Rails.root.join('tmp', dir_name, 'images')
        @pdf_working_dir = Rails.root.join('tmp', dir_name, 'pdfs')
      end

      def member_file_sets
        @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
      end

      def image_file_sets
        member_file_sets.select { |fs| fs.original_file.mime_type.start_with?('image/') }
      end

      def pdf_file_sets
        member_file_sets.select { |fs| fs.original_file.mime_type.start_with?('application/pdf') }
      end

      def copy_images_to_working_dir
        image_file_sets.each_with_index do |fs, _i|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          destination_io = File.open("#{@working_dir}/images/#{fs.original_file.original_filename}", 'w')

          IO.copy_stream(io.stream, destination_io)
          destination_io.close
        end
      end

      def copy_pdfs_to_working_dir
        pdf_file_sets.each_with_index do |fs, _i|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          destination_io = File.open(
            "#{@working_dir}/pdfs/#{@work.title&.first&.gsub(/\s+/, '_') || 'working_pdf'}.pdf", 'w'
          )

          IO.copy_stream(io.stream, destination_io)
          destination_io.close
        end
        @pdf_working_path = "#{@working_dir}/pdfs/#{@work.title&.first&.gsub(/\s+/, '_') || 'working_pdf'}.pdf"
      end

      def ocr_pdf(input_path, output_path)
        cmd = "ocrmypdf --skip-text #{input_path} #{output_path}"
        `#{cmd}`
      end

      def join_images_to_pdf
        title = @work.title&.first&.gsub(/\s+/, '_') || @work.id
        @image_joined_pdf_path = "#{@working_dir}/#{title}.pdf"

        cmd = "magick convert #{@working_dir}/images/* #{@image_joined_pdf_path}"

        `#{cmd}`
      end

      def attach_pdf_to_work(pdf_path)
        user = User.find_by(email: @work.depositor)
        return unless File.exist?(pdf_path) && user

        title = @work.title&.first&.gsub(/\s+/, '_') || @work.id
        filename = "#{title}.pdf"

        # Create and persist the FileSet first to ensure it has a stable id
        file_set = Hyrax::FileSet.new(title: [filename], label: filename)
        file_set = Hyrax.persister.save(resource: file_set)

        begin
          file_io = File.open(pdf_path, 'rb')

          Hyrax::ValkyrieUpload.file(
            filename: filename,
            file_set: file_set,
            io: file_io,
            user: user,
            mime_type: 'application/pdf',
            skip_derivatives: true
          )

          @work.member_ids << file_set.id
          @work.representative_id = file_set.id
          Hyrax.persister.save(resource: @work)
          Hyrax.index_adapter.save(resource: file_set)
          Hyrax.index_adapter.save(resource: @work)
        ensure
          file_io&.close
        end
      end

      def cleanup_working_dir
        FileUtils.rm_rf(@working_dir)
      end
    end
  end
end
