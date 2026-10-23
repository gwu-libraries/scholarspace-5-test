# frozen_string_literal: true

class JournalIssue < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:journal_issue)
  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
