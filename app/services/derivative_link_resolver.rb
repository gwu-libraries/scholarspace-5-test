# frozen_string_literal: true

class DerivativeLinkResolver
  include ::MimeTypeConstants
  include ThumbnailTagConstants
  include StringNormalization

  def initialize(members:)
    @members = Array(members)
  end

  def self.source_file_set_id_for(member)
    new(members: []).source_file_set_id_for(member)
  end

  def self.related_url_values_for(member)
    new(members: []).related_url_values_for(member)
  end

  def transcripts_by_source_id
    @transcripts_by_source_id ||= build_indexes[:transcripts]
  end

  def hocr_by_source_id
    @hocr_by_source_id ||= build_indexes[:hocr]
  end

  def transcript_members_for(source_id)
    transcripts_by_source_id.fetch(source_id.to_s, [])
  end

  def hocr_member_for(source_id)
    hocr_by_source_id[source_id.to_s]
  end

  def source_file_set_id_for(member)
    entry = related_url_values_for(member)
            .find { |value| value.start_with?(SOURCE_FILE_SET_ID_PREFIX) }
    entry.to_s.sub(SOURCE_FILE_SET_ID_PREFIX, '')
  end

  def related_url_values_for(member)
    related_url_candidates_for(member)
  end

  def transcript_file_set?(member)
    return true if member.respond_to?(:vtt?) && member.vtt?

    mime = normalize_mime_type(member_mime_type(member))
    mime == VTT_MIME_TYPE
  end

  def hocr_file_set?(member)
    return true if member.respond_to?(:hocr?) && member.hocr?

    mime = normalize_mime_type(member_mime_type(member))
    mime == HOCR_MIME_TYPE
  end

  private

  attr_reader :members

  def build_indexes
    transcripts = Hash.new { |hash, key| hash[key] = [] }
    hocr = {}

    members.each do |member|
      next unless member_file_set?(member)

      is_transcript = transcript_file_set?(member)
      is_hocr = hocr_file_set?(member)
      next unless is_transcript || is_hocr

      source_id = source_file_set_id_for(member)
      if source_id.blank?
        derivative_type = is_transcript ? 'transcript' : 'hocr'
        log_missing_source_linkage(member, derivative_type: derivative_type)
        next
      end

      if is_transcript
        transcripts[source_id] << member
        next
      end

      next unless is_hocr

      existing = hocr[source_id]
      hocr[source_id] = pick_preferred_hocr(existing, member)
    end

    { transcripts: transcripts, hocr: hocr }
  end

  def member_file_set?(member)
    return member.file_set? if member.respond_to?(:file_set?)

    true
  end

  def pick_preferred_hocr(existing, candidate)
    return candidate unless existing

    hocr_score(existing) >= hocr_score(candidate) ? existing : candidate
  end

  def hocr_score(member)
    mime = normalize_mime_type(member_mime_type(member))
    mime == HOCR_MIME_TYPE ? 2 : 0
  end

  def member_mime_type(member)
    return member.mime_type.to_s if member.respond_to?(:mime_type)

    source = member.respond_to?(:model) ? member.model : member
    original_file = source.respond_to?(:original_file) ? source.original_file : nil
    return '' unless original_file&.respond_to?(:mime_type)

    original_file.mime_type.to_s
  end

  def member_filename(member)
    source = member.respond_to?(:model) ? member.model : member
    if source.respond_to?(:original_file)
      original_filename = source.original_file&.original_filename.to_s
      return original_filename if original_filename.present?
    end

    return member.label.to_s if member.respond_to?(:label) && member.label.present?
    return member.title.to_a.first.to_s if member.respond_to?(:title) && member.title.present?

    ''
  end

  def related_url_candidates_for(member)
    source = member.respond_to?(:model) ? member.model : member
    candidates = []
    candidates.concat(Array(source.related_url)) if source.respond_to?(:related_url)

    if member.respond_to?(:solr_document)
      candidates.concat(Array(member.solr_document['related_url_tesim']))
    end

    candidates.map(&:to_s)
  end

  def log_missing_source_linkage(member, derivative_type:)
    nil
  end
end
