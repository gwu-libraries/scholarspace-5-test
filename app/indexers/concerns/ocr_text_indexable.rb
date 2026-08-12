# frozen_string_literal: true

require 'digest'
require 'fileutils'

module OcrTextIndexable
  extend ActiveSupport::Concern
  include Constants::DerivativeFilenameConstants
  include MemberQueries
  include FileOperations

  # We are using https://dbmdz.github.io/solr-ocrhighlighting/latest/
  # for ocr text indexing that includes bounding boxes. 

  # essentially this points a field ("ocr_text") in the solr document 
  # to a stored HOCR document.

  # HOWEVER! because our hocr documents are being persisted in fedora on S3, in
  # case they have been fixed or modified and we want to maintain those changes,
  # we need them available on disk as well. This creates a copy of the HOCR
  # document from fedora on local disk and updates the :ocr_text pointe in the 
  # solr document. 

  # this does create an additional hocr document in the cache whenever a new version
  # of one is deposited, but it updates the pointer to the new doc. These won't be updated
  # with much frequency and are just xml files, so ¯\_(ツ)_/¯

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
      member = find_member_by_id(member_id)
      next unless member

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
    return false if filename.casecmp?(READING_MODE_HOCR_FILENAME)

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

    copied = persist_ocr_file(file_identifier: file_identifier, pointer_path: pointer_path)
    pointer_path if copied
  end

  def ocr_pointer_path(file_identifier:, original_filename:)
    extension = File.extname(original_filename).presence || '.hocr'
    digest = Digest::SHA256.hexdigest(file_identifier)
    File.join(ocr_pointer_root, "#{digest}#{extension}")
  end

  def persist_ocr_file(file_identifier:, pointer_path:)
    ensure_directory_exists(File.dirname(pointer_path))
    copied_path = copy_file_to_disk(file_identifier, pointer_path)
    copied_path.present?
  end



  def ocr_pointer_root
    configured_root = '/app/scholarspace/tmp/cache/solr-ocr-index-cache'
    return configured_root if cache_root_writable?(configured_root)

    fallback_root = ENV.fetch('SOLR_OCR_INDEX_CACHE_ROOT', '/tmp/scholarspace-cache/solr-ocr-index-cache')
    ensure_directory_exists(fallback_root)
    fallback_root
  end

  def cache_root_writable?(path)
    ensure_directory_exists(path)
    File.writable?(path)
  rescue SystemCallError
    false
  end
end
