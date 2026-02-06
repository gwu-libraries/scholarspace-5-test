# frozen_string_literal: true

module DerivativesServices
  class WorkImagesToPdfDerivativesService
    def initialize(work)
      @work = work
    end

    def create_derivatives
      prepare_working_directory

      # TODO: copy over the implementation from other branch

      cleanup_working_directory

      raise StandardError, 'Not implemented yet'
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
  end
end
