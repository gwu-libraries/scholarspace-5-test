# frozen_string_literal: true

require 'mini_magick'

module DerivativeServices
  module Archival
    class ArchivalImageDerivativesService
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

        if image_file_sets&.count == 1
          # just create a thumbnail
        elsif image_file_sets.present?
          copy_images_to_working_dir
          # then thumbnail for each?
        elsif pdf_file_sets.present?
          copy_pdfs_to_working_dir
          split_pdf_to_images

          Dir.glob(File.join(@image_working_dir, '*')).each do |image_path|
            attach_image_to_work(image_path)
          end
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

      def copy_pdfs_to_working_dir
        pdf_file_sets.each_with_index do |fs, _index|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          destination_io = File.open("#{@working_dir}/pdfs/#{fs.original_file.original_filename}", 'wb')
          IO.copy_stream(io, destination_io)
          destination_io.close
        end
        @pdf_working_path = "#{@working_dir}/pdfs/#{pdf_file_sets.first.original_file.original_filename}"
      end

      def copy_images_to_working_dir
        image_file_sets.each_with_index do |fs, _index|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          destination_io = File.open("#{@working_dir}/images/#{fs.original_file.original_filename}", 'wb')
          IO.copy_stream(io, destination_io)
          destination_io.close
        end
      end

      def split_pdf_to_images
        pdf_path = @pdf_working_path
        output_pattern = File.join(@image_working_dir, 'page_%04d.png')

        MiniMagick::Tool::Convert.new do |convert|
          convert.density(300)
          convert << pdf_path
          convert << output_pattern
        end
      end

      def attach_image_to_work(image_path)
        user = User.find_by(email: @work.depositor)

        filename = File.basename(image_path)

        file_set = Hyrax::FileSet.new(title: [filename], label: filename)
        file_set = Hyrax.persister.save(resource: file_set)

        begin
          file_io = File.open(image_path, 'rb')

          Hyrax::ValkyrieUpload.file(
            filename: filename,
            file_set: file_set,
            io: file_io,
            user: user,
            mime_type: 'image/png',
            skip_derivatives: true
          )

          @work.member_ids << file_set.id
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
