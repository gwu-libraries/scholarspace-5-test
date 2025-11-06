# frozen_string_literal: true

class DerivedPageIndexer < Hyrax::Indexers.PcdmObjectIndexer(DerivedPage)
  include Hyrax::Indexer(:basic_metadata)
  include Hyrax::Indexer(:derived_page)

  # Sets the ocr_text field in the index to the xml hOCR file path
  def to_solr
    super.tap do |index_document|
      if resource.representative_id.present?
        path =
          Hyrax::DerivativePath.derivative_path_for_reference(
            resource.representative_id,
            "xml"
          )

        index_document[:ocr_text] = path if File.exist?(path)
      end
    end
  end
end
