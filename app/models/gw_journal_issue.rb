# frozen_string_literal: true

class GwJournalIssue < AcademicDocument
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:academic_document)
  include Hyrax.Schema(:gw_journal_issue)
end
