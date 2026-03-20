# frozen_string_literal: true

require 'digest'
require 'fileutils'

module OcrTextIndexable
  extend ActiveSupport::Concern

  # We are using https://dbmdz.github.io/solr-ocrhighlighting/latest/
  # for ocr text indexing that includes bounding boxes. 

  # essentially this points a field ("ocr_text") in the solr document 
  # to a stored HOCR document.

  # HOWEVER! because our hocr documents are being persisted in fedora,
  # we need them available on disk as well.

  included do
    # Override to_solr to include OCR source pointers for Solr OCR Highlighting.
  end

  def to_solr
    super.tap do |index_document|
      ocr_source_pointer = extract_ocr_source_pointer
      index_document[:ocr_text] = ocr_source_pointer if ocr_source_pointer.present?
    end
  end

  private

  def extract_ocr_source_pointer
    hocr_pointers = resource.member_ids.filter_map do |member_id|
      member = Hyrax.query_service.find_by(id: member_id)
      files = hocr_files_for_member(member)
      next if files.empty?

      files.filter_map { |file| source_pointer_for(file) }
    end.compact

    hocr_pointers.join('+') if hocr_pointers.any?
  end

  def hocr_file?(file)
    return false unless file.respond_to?(:original_filename)

    filename = file.original_filename.to_s
    return false if filename.empty?

    filename.downcase.end_with?('.hocr')
  end

  def hocr_files_for_member(member)
    return [] unless member.respond_to?(:original_file)

    file = member.original_file
    return [] unless file && hocr_file?(file)

    [file]
  end

  def source_pointer_for(file)
    return nil unless file.respond_to?(:file_identifier)

    file_identifier = file.file_identifier
    return nil if file_identifier.blank?

    file_identifier = file_identifier.to_s
    pointer_path = ocr_pointer_path(
      file_identifier: file_identifier,
      original_filename: file.original_filename.to_s
    )

    persist_ocr_file(file_identifier: file_identifier, pointer_path: pointer_path)
    pointer_path
  end

  def ocr_pointer_path(file_identifier:, original_filename:)
    extension = File.extname(original_filename).presence || '.hocr'
    digest = Digest::SHA256.hexdigest(file_identifier)
    File.join(ocr_pointer_root, "#{digest}#{extension}")
  end

  def persist_ocr_file(file_identifier:, pointer_path:)
    io = Hyrax.storage_adapter.find_by(id: file_identifier)
    FileUtils.mkdir_p(File.dirname(pointer_path))

    File.open(pointer_path, 'wb') do |destination_io|
      IO.copy_stream(io.stream, destination_io)
    end
  end

  def ocr_pointer_root
    '/solr-ocr-index-cache'
  end
end