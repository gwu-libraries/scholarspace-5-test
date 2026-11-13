# frozen_string_literal: true

class Resolvers::WorkViewerResolver
  include ::Derivatives::Constants::DerivativeTypeConstants
  include ::Derivatives::Constants::MimeTypeConstants
  include ::Derivatives::Constants::ThumbnailTagConstants

  def initialize(presenter:)
    @presenter = presenter
  end

  def images?
    members.any? do |member|
      member_mime_type(member).start_with?(IMAGE_MIME_PREFIX) &&
        !service_file_member?(member) &&
        presentation_members_by_source_id[member.id.to_s].present?
    end
  end

  def pdf_file_id
    reading_mode_pdf = pdf_members.find { |member| reading_mode_pdf_file_set?(member) }
    return reading_mode_pdf.id.to_s if reading_mode_pdf

    pdf_members.reject { |member| service_file_member?(member) }.each do |source|
      presentation = preferred_pdf_derivative_for_source(source)
      return presentation.id.to_s if presentation
    end

    nil
  end

  def preferred_download_member(member_id)
    member = member_index[member_id.to_s] || find_member_file_set(member_id)
    return nil unless member
    return member if service_file_member?(member)
    return preferred_pdf_derivative_for_source(member) if pdf_file_set?(member)

    presentation_members_by_source_id[member.id.to_s]
  end

  def hocr_file_id(pdf_file_id)
    return nil if pdf_file_id.blank?

    pdf = member_index[pdf_file_id.to_s] || find_member_file_set(pdf_file_id)
    return nil unless pdf

    if reading_mode_pdf_file_set?(pdf)
      reading_mode_hocr = members.find do |member|
        hocr_file_set?(member) &&
          file_set_filename(member) == ::Derivatives::Constants::DerivativeFilenameConstants::READING_MODE_HOCR_FILENAME
      end
      return reading_mode_hocr.id.to_s if reading_mode_hocr
    end

    derivative_link_resolver.hocr_member_for(pdf.id)&.id&.to_s
  end

  private

  attr_reader :presenter

  def members
    @members ||= if presenter.respond_to?(:member_presenters)
                   Array(presenter.member_presenters)
                 elsif presenter.respond_to?(:member_ids)
                   Array(presenter.member_ids).filter_map { |id| find_member_file_set(id) }
                 else
                   []
                 end
  end

  def member_index
    @member_index ||= members.index_by { |member| member.id.to_s }
  end

  def pdf_members
    @pdf_members ||= members.select { |member| member && pdf_file_set?(member) }
  end

  def find_member_file_set(member_id)
    @members_by_id ||= {}
    @members_by_id[member_id.to_s] ||= Hyrax.query_service.find_by(id: member_id)
  end

  def preferred_pdf_derivative_for_source(source)
    pdf_members.find do |candidate|
      presentation_version_pdf_file_set?(candidate) &&
        derivative_link_resolver.source_file_set_id_for(candidate) == source.id.to_s
    end
  end

  def presentation_members_by_source_id
    @presentation_members_by_source_id ||= begin
      grouped = members.each_with_object({}) do |candidate, map|
        next unless service_file_member?(candidate)

        source_id = derivative_link_resolver.source_file_set_id_for(candidate)
        next if source_id.blank?

        (map[source_id] ||= []) << candidate
      end
      grouped.transform_values { |linked| preferred_presentation_member(linked) }
    end
  end

  def preferred_presentation_member(linked)
    pdfs = linked.select { |candidate| pdf_file_set?(candidate) }
    return pdfs.find { |candidate| presentation_version_pdf_file_set?(candidate) } if pdfs.present?

    tagged = linked.find { |candidate| presentation_version_tagged?(candidate) }
    return tagged if tagged

    linked.find { |candidate| file_set_filename(candidate).downcase.include?(PRESENTATION_VERSION_FILENAME_FRAGMENT) }
  end

  def presentation_version_tagged?(member)
    derivative_link_resolver.related_url_values_for(member)
                            .include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
  end

  def presentation_version_pdf_file_set?(member)
    pdf_file_set?(member) && service_file_member?(member) && presentation_version_tagged?(member)
  end

  def reading_mode_pdf_file_set?(member)
    file_set_filename(member) == ::Derivatives::Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
  end

  def derivative_link_resolver
    @derivative_link_resolver ||= Resolvers::DerivativeLinkResolver.new(members: members)
  end

  def pdf_file_set?(member)
    return member.pdf? if member.respond_to?(:pdf?)

    member_mime_type(member) == PDF_MIME_TYPE
  end

  def hocr_file_set?(member)
    return member.hocr? if member.respond_to?(:hocr?)

    member_mime_type(member) == HOCR_MIME_TYPE
  end

  def file_set_filename(member)
    source = member.respond_to?(:model) ? member.model : member
    if source.respond_to?(:original_file)
      original_name = source.original_file&.original_filename.to_s
      return original_name if original_name.present?
    end

    return member.file_display_name.to_s if member.respond_to?(:file_display_name)
    return member.label.to_s if member.respond_to?(:label) && member.label.present?
    return member.title.to_a.first.to_s if member.respond_to?(:title) && member.title.present?

    ''
  end

  def member_mime_type(member)
    return member.mime_type.to_s.downcase if member.respond_to?(:mime_type)

    source = member.respond_to?(:model) ? member.model : member
    original_file = source.respond_to?(:original_file) ? source.original_file : nil
    return '' unless original_file&.respond_to?(:mime_type)

    original_file.mime_type.to_s.downcase
  end

  def service_file_member?(member)
    source = member.respond_to?(:model) ? member.model : member
    return source.service_file if source.respond_to?(:service_file)

    if member.respond_to?(:solr_document)
      return ActiveModel::Type::Boolean.new.cast(member.solr_document['service_file_bsi'])
    end

    false
  end
end
