# frozen_string_literal: true

require 'open3'
require 'tempfile'

module EmbeddedPdfTextIndexable
  private

  def extract_pdf_plain_text(content)
    Tempfile.create(['scholarspace-index', '.pdf']) do |pdf_file|
      pdf_file.binmode
      pdf_file.write(content)
      pdf_file.flush
      stdout, _stderr, status = Open3.capture3('pdftotext', '-q', pdf_file.path, '-')
      return nil unless status.success?

      normalize_plain_text(stdout)
    end
  rescue StandardError
    nil
  end
end