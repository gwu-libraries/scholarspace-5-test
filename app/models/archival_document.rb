# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalDocument < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:archival_document)

  include IiifPrint.model_configuration(
            pdf_splitter_service: IiifPrint::SplitPdfs::DerivativeRodeoSplitter,
            pdf_split_child_model: DerivedPage,
            derivative_service_plugins: [
              IiifPrint::PDFDerivativeService,
              IiifPrint::TextExtractionDerivativeService,
              IiifPrint::TIFFDerivativeService
            ]
          )
end
