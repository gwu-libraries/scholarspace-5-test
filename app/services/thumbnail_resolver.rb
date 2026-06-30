# frozen_string_literal: true

class ThumbnailResolver
  include ::ThumbnailFilenameConstants
  include ThumbnailTagConstants

  def initialize(
    query_service: Hyrax.query_service,
    custom_queries: Hyrax.custom_queries,
    routes: Hyrax::Engine.routes.url_helpers
  )
    @query_service = query_service
    @custom_queries = custom_queries
    @routes = routes
  end

  def persisted_thumbnail_url_for_file_set(file_set_id:, host:)
    return nil if file_set_id.blank? || host.blank?

    thumbnail = generated_thumbnail_file_set_for_source(file_set_id)
    return @routes.download_url(id: thumbnail.id, host: host) if thumbnail

    @routes.download_url(id: file_set_id, file: 'thumbnail', host: host)
  end

  def thumbnail_path_for_member(member:, service_members: [], thumbnail_members_by_source_id_map: nil)
    thumbnail_member = if thumbnail_service_member?(member)
                         member
                       else
                         map = thumbnail_members_by_source_id_map || thumbnail_members_by_source_id(service_members)
                         map[member.id.to_s]
                       end

    return @routes.download_path(id: thumbnail_member.id, locale: nil) if thumbnail_member

    @routes.download_path(id: member.id, file: 'thumbnail', locale: nil)
  end

  def thumbnail_paths_by_member_id(members:, service_members: [])
    source_map = thumbnail_members_by_source_id(service_members)

    Array(members).each_with_object({}) do |member, map|
      map[member.id.to_s] = thumbnail_path_for_member(
        member: member,
        service_members: service_members,
        thumbnail_members_by_source_id_map: source_map
      )
    end
  end

  def representative_thumbnail_path_for_work(work:)
    return nil unless work.respond_to?(:thumbnail_id) && work.thumbnail_id.present?

    thumbnail = find_resource(work.thumbnail_id)
    return nil unless representative_thumbnail?(thumbnail)

    @routes.download_path(id: thumbnail.id, locale: nil)
  end

  private

  def generated_thumbnail_file_set_for_source(file_set_id)
    source_file_set = find_resource(file_set_id)
    return nil unless source_file_set

    work = @custom_queries.find_parent_work(resource: source_file_set)
    return nil unless work

    candidate_name = generated_thumbnail_name(source_file_set.original_file&.original_filename.to_s)
    return nil if candidate_name.blank?

    Array(work.member_ids).lazy.map { |member_id| find_resource(member_id) }.compact.find do |member|
      next false unless service_file?(member)

      title_match = Array(member.title).any? { |value| value.to_s == candidate_name }
      name_match = member.original_file&.original_filename.to_s == candidate_name
      title_match || name_match
    end
  end

  def thumbnail_members_by_source_id(service_members)
    cache_key = service_members_cache_key(service_members)
    cache = thumbnail_members_by_source_id_cache
    return cache[cache_key] if cache.key?(cache_key)

    cache[cache_key] = Array(service_members).each_with_object({}) do |service_member, map|
      next unless thumbnail_service_member?(service_member)
      next if representative_thumbnail_tagged_member?(service_member)

      source_id = source_file_set_id(service_member)
      next if source_id.blank?

      map[source_id] ||= service_member
    end
  end

  def service_members_cache_key(service_members)
    Array(service_members).map { |member| member.id.to_s }.sort.join('|')
  end

  def source_file_set_id(member)
    DerivativeLinkResolver.source_file_set_id_for(member)
  end

  def thumbnail_service_member?(member)
    label = member_label(member).downcase
    return true if label.include?(THUMBNAIL_FILENAME_FRAGMENT)

    derivative_thumbnail_tagged_member?(member) || representative_thumbnail_tagged_member?(member)
  end

  def derivative_thumbnail_tagged_member?(member)
    DerivativeLinkResolver.related_url_values_for(member).any? { |value| value == THUMBNAIL_DERIVATIVE_TAG }
  end

  def representative_thumbnail_tagged_member?(member)
    DerivativeLinkResolver.related_url_values_for(member).any? { |value| value.start_with?(REPRESENTATIVE_THUMBNAIL_TAG_PREFIX) }
  end

  def member_label(member)
    return member.label.to_s if member.respond_to?(:label) && member.label.present?
    return member.title.to_a.first.to_s if member.respond_to?(:title) && member.title.present?

    ''
  end

  def representative_thumbnail?(thumb)
    return false unless thumb&.respond_to?(:service_file) && thumb.service_file

    title = Array(thumb.title).map(&:to_s)
    filename = thumb.original_file&.original_filename.to_s
    title.include?(REPRESENTATIVE_THUMBNAIL_FILENAME) || filename == REPRESENTATIVE_THUMBNAIL_FILENAME
  end

  def generated_thumbnail_name(filename)
    stem = File.basename(filename.to_s, File.extname(filename.to_s))
    sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
    return nil if sanitized.blank?

    "#{sanitized}#{GENERATED_THUMBNAIL_SUFFIX}"
  end

  def service_file?(resource)
    resource.respond_to?(:service_file) && resource.service_file
  end

  def find_resource(id)
    key = id.to_s
    return nil if key.blank?

    cache = resource_cache
    return cache[key] if cache.key?(key)

    cache[key] = begin
      @query_service.find_by(id: key)
    rescue Valkyrie::Persistence::ObjectNotFoundError
      begin
        @query_service.find_by_alternate_identifier(alternate_identifier: key)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        nil
      end
    end
  end

  def resource_cache
    @resource_cache ||= {}
  end

  def thumbnail_members_by_source_id_cache
    @thumbnail_members_by_source_id_cache ||= {}
  end

end