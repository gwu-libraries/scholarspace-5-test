# frozen_string_literal: true

module CustomDerivativesServices
  class ImagesToPdfDerivativesService
    def initialize(work)
      @work = work
      @working_dir = nil
      @joined_pdf_path = nil
    end

    def call
      prepare_working_directory
      copy_images_to_working_dir
      join_images_to_pdf("#{@working_dir}/images")
      attach_pdf_to_work(@joined_pdf_path)
    rescue StandardError
    ensure
      cleanup_working_directory
    end

    def prepare_working_directory
      # just using timestamp for naming unique temp directory

      dir_name = Time.now.to_i.to_s
      @working_dir = Rails.root.join('tmp', dir_name)

      Dir.mkdir(@working_dir)
      Dir.mkdir("#{@working_dir}/images")
      Dir.mkdir("#{@working_dir}/pdfs")
    end

    def cleanup_working_directory
      FileUtils.rm_rf(@working_dir)
    end

    def member_file_sets
      @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
    end

    def image_file_sets
      member_file_sets.select { |fs| fs.original_file.mime_type.start_with?('image/') }
    end

    def copy_images_to_working_dir
      image_file_sets.each_with_index do |fs, _i|
        io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
        destination_io = File.open("#{@working_dir}/images/#{fs.original_file.original_filename}", 'w')

        IO.copy_stream(io.stream, destination_io)
        destination_io.close
      end
    end

    def join_images_to_pdf(image_dir_path)
      title = @work.title&.first&.gsub(/\s+/, '_') || @work.id
      @joined_pdf_path = "#{@working_dir}/#{title}.pdf"

      cmd = "magick convert #{image_dir_path}/* #{@joined_pdf_path}"

      `#{cmd}`
    end

    def assign_file_set_as_representative(file_set)
      @work.representative_id = file_set.id if @work.respond_to?(:representative_id)
    end

    def attach_pdf_to_work(pdf_path)
      user = User.find_by(email: @work.depositor)

      return unless File.exist?(pdf_path) && user

      file_io = File.open(pdf_path, 'rb')
      title = @work.title&.first&.gsub(/\s+/, '_') || @work.id
      filename = "#{title}.pdf"
      permissions = @work.permission_manager.acl.permissions.map(&:to_hash)

      uploaded_file = Hyrax::UploadedFile.create(
        user: user,
        file: file_io
      )

      file_set = Hyrax::WorkUploadsHandler.new(work: @work)
                                          .add(files: [uploaded_file])
                                          .attach

      # this mostly works, but triggers injest job, which in turn triggers derivative generation
      # which we don't want because this *is* a derivative.
      # require 'pry'
      # binding.pry
      # file_set = Hyrax::FileSet.new(title: [filename], label: 'JoinedPDF')
      # file_set = Hyrax.persister.save(resource: file_set)

      # file_set.visibility = @work.visibility
      # uploaded_file = Hyrax::ValkyrieUpload.file(
      #  filename: filename,
      # file_set: file_set,
      # io: file_io,
      # user: user,
      # use: Hyrax::FileMetadata::Use::SERVICE_FILE,
      # mime_type: 'application/pdf',
      # skip_derivatives: true
      # )

      file_io&.close

      assign_file_set_as_representative(file_set)

      Hyrax.persister.save(resource: @work)
      Hyrax.persister.save(resource: file_set)
      Hyrax.index_adapter.save(resource: @work)
      Hyrax.index_adapter.save(resource: file_set)
    end
  end
end
