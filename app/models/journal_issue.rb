# frozen_string_literal: true

class JournalIssue < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:journal_issue)
  end
  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
