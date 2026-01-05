require 'open3'
require 'tmpdir'

module DerivativeServices
  module Archival
    class ArchivalTextDerivativesService
      def initialize(work)
        @work = work
        @dest_dir = nil
        @working_dir = nil
      end

      # copy all of the images to a tmp working directory
      # once they are there, run the join command to create the pdf
      # and persist it
      def prepare_working_dir
        # @working_dir = Dir.mktmpdir
        @working_dir = Dir.mkdir(Rails.root.join("tmp", "x"))
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
        # remove index, include file name, just temporary
        image_file_sets.each_with_index do |fs, i|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          # require 'pry'; binding.pry
          destination_io = File.open("#{@working_dir}/#{i}.tiff", 'w') # Open for writing

          # ALEX 
          IO.copy_stream(io.stream, destination_io)
          destination_io.close
        end
      end

      def copy_pdfs_to_working_dir
      end

      def create_derivatives
        prepare_working_dir

        copy_images_to_working_dir
        require 'pry'; binding.pry

        copy_pdfs_to_working_dir

        # IO.copy_stream(s, "#{@working_dir}_1.tiff")
        # y = image_file_sets.first.original_file.file_identifier

        join_images_to_pdf(image_file_sets) unless image_file_sets.empty?

        # maybe extract text after joining if images
      end

      def extract_text(file_set)
        # Logic to extract text from the given file_set
        Hyrax.logger.debug do
          puts "Extracting text from file set #{file_set.id}"
        end
        # Actual text extraction code would go here
      end

      def join_images_to_pdf(image_file_sets)
        # Logic to join image file sets into a single PDF
        Hyrax.logger.debug do
          puts "Joining images into PDF for file sets #{image_file_sets.map(&:id).join(', ')}"
        end
        # Actual PDF creation code would go here
      end
    end
  end
end
