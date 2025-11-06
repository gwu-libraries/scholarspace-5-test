require "derivative_rodeo"
# rubocop:disable Lint/UnusedBlockArgument
IiifPrint.config do |config|
  # NOTE: WorkTypes and models are used synonymously here.
  # Add models to be excluded from search so the user
  # would not see them in the search results.
  # by default, use the human readable versions like:
  # @example
  #   # config.excluded_model_name_solr_field_values = ['Generic Work', 'Image']
  #
  config.excluded_model_name_solr_field_values = ["Derived Page"]

  config.unique_child_title_generator_function =
    lambda do |original_pdf_path:, image_path:, parent_work:, page_number:, page_padding:|
      identifier = parent_work.id
      filename = File.basename(original_pdf_path)
      page_suffix =
        "#{(page_number.to_i + 1).to_s.rjust(page_padding.to_i, "0")}"
      "#{parent_work.title.first} - Page #{page_suffix}"
    end
  # Add configurable solr field key for searching,
  # default key is: 'human_readable_type_sim'
  # if another key is used, make sure to adjust the
  # config.excluded_model_name_solr_field_values to match
  # @example
  #   config.excluded_model_name_solr_field_key = 'some_solr_field_key'

  # if Rails.env.development?
  #   if DerivativeRodeo.config.aws_s3_access_key_id.present? && DerivativeRodeo.config.aws_s3_secret_access_key.present?
  #     Rails.logger.info("DerivativeRodeo S3 Credentials detected using 's3' for IiifPrint::DerivativeRodeoService.preprocessed_location_adapter_name")
  #     IiifPrint::DerivativeRodeoService.preprocessed_location_adapter_name = 's3'
  #   else
  #     Rails.logger.info("DerivativeRodeo S3 Credentials not-detected using 'file' for IiifPrint::DerivativeRodeoService.preprocessed_location_adapter_name")
  #   end
  # end
  IiifPrint::DerivativeRodeoService.parent_work_identifier_property_name = "id"
  IiifPrint::DerivativeRodeoService.preprocessed_location_adapter_name = "file"

  config.persistence_adapter = IiifPrint::PersistenceLayer::ValkyrieAdapter
  # config.additional_tesseract_options = "-l eng_best"

  config.uv_config_path = "/uv/config/default"
  config.uv_base_path = "/uv/uv.html"
end
# rubocop:enable Lint/UnusedBlockArgument
