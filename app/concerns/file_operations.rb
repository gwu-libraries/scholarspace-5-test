# frozen_string_literal: true

module FileOperations
  extend ActiveSupport::Concern

  # Copy a file from storage to a local disk path
  def copy_file_to_disk(file_identifier, destination_path)
    return nil unless file_identifier.present?
    return nil unless destination_path.present?

    begin
      io = Hyrax.storage_adapter.find_by(id: file_identifier)
      return nil unless io

      File.open(destination_path, 'wb') do |destination_io|
        IO.copy_stream(io.stream, destination_io)
      end

      destination_path
    rescue StandardError => e
      Rails.logger.error("Failed to copy file #{file_identifier} to #{destination_path}: #{e.message}")
      nil
    end
  end

  # Read the content of a file from storage
  def read_file_content(file)
    return nil unless file.respond_to?(:file_identifier)

    file_identifier = file.file_identifier
    return nil if file_identifier.blank?

    begin
      io = find_storage_file_by_id(file_identifier)
      return nil unless io

      io.stream.read
    rescue StandardError => e
      Rails.logger.error("Failed to read file #{file_identifier}: #{e.message}")
      nil
    end
  end

  # Find a storage file by its identifier
  def find_storage_file_by_id(file_identifier)
    Hyrax.storage_adapter.find_by(id: file_identifier)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  # Ensure a directory exists, creating it and parent directories if needed
  def ensure_directory_exists(path)
    return nil unless path.present?

    begin
      FileUtils.mkdir_p(path)
      path
    rescue StandardError => e
      Rails.logger.error("Failed to create directory #{path}: #{e.message}")
      nil
    end
  end
end
