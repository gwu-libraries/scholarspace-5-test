# frozen_string_literal: true

#class JournalIssueIndexer < Hyrax::Indexers.PcdmObjectIndexer(
#  JournalIssue
#)
class JournalIssueIndexer < Hyrax::ValkyrieWorkIndexer
  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:basic_metadata)
    include Hyrax::Indexer(:journal_issue)
  end

  include MemberFullTextAggregatable
  include ContributorFacetIndexable
  include YearCreatedIndexable

  check_if_flexible(JournalIssue)

  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
