module IiifSearchAnnotationDecorator
  def file_set_id
    # override - can't call .file_set? on a hash
    return document["id"] if document['has_model_ssim'] == ['Hyrax::FileSet']

    file_set_ids = document["member_ids_ssim"]
    raise "#{self.class}: NO FILE SET ID" if file_set_ids.blank?

    # Since a parent work's `member_ids_ssim` can contain child work ids as well as file set ids,
    # this will ensure that the file set id is indeed a `FileSet`
    file_set_ids.detect { |id| SolrDocument.find(id).file_set? }
  end
end
::BlacklightIiifSearch::IiifSearchAnnotation.prepend(IiifSearchAnnotationDecorator)
