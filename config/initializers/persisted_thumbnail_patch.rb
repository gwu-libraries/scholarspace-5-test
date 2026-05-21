# frozen_string_literal: true

Rails.application.config.to_prepare do
  module Scholarspace
    # Shared helpers for persisted thumbnail logic
    module PersistedThumbnailHelpers
      REPRESENTATIVE_THUMBNAIL_FILENAME = 'REPRESENTATIVE_THUMBNAIL.jpg'

      def representative_thumbnail?(thumb)
        return false unless thumb&.respond_to?(:file_set?) && thumb.file_set?
        return false unless thumb.respond_to?(:service_file) && thumb.service_file

        title = Array(thumb.title).map(&:to_s)
        filename = thumb.original_file&.original_filename.to_s
        title.include?(REPRESENTATIVE_THUMBNAIL_FILENAME) || filename == REPRESENTATIVE_THUMBNAIL_FILENAME
      end

      def generated_thumbnail_name(filename)
        stem = File.basename(filename, File.extname(filename))
        sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
        return nil if sanitized.blank?

        "#{sanitized}_THUMBNAIL.jpg"
      end

      def find_work_by_id(work_id)
        Hyrax.query_service.find_by(id: work_id)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: work_id)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        nil
      end
    end

    # ============================================================================
    # IIIF Manifest Thumbnail Patches
    # ============================================================================

    module ManifestCanvasThumbnails
      include PersistedThumbnailHelpers

      def manifest_for(presenter:)
        manifest = normalize_manifest_json(super)
        reject_thumbnail_derivative_canvases!(manifest: manifest)
        sort_canvases_alphabetically!(manifest: manifest)
        apply_canvas_thumbnails!(manifest: manifest, presenter: presenter)
      end

      private

      def sort_canvases_alphabetically!(manifest:)
        sequences = manifest['sequences']
        return manifest unless sequences.is_a?(Array)

        first_sequence = sequences.first
        return manifest unless first_sequence.is_a?(Hash)

        canvases = first_sequence['canvases']
        return manifest unless canvases.is_a?(Array)

        canvases.sort_by! { |canvas| canvas['label'].to_s.downcase }
        manifest
      end

      def reject_thumbnail_derivative_canvases!(manifest:)
        sequences = manifest['sequences']
        return manifest unless sequences.is_a?(Array)

        first_sequence = sequences.first
        return manifest unless first_sequence.is_a?(Hash)

        canvases = first_sequence['canvases']
        return manifest unless canvases.is_a?(Array)

        canvases.reject! do |canvas|
          thumbnail_derivative_canvas_label?(canvas['label'])
        end

        manifest
      end

      def thumbnail_derivative_canvas_label?(label)
        value = label.to_s.strip
        return false if value.blank?

        value.casecmp('REPRESENTATIVE_THUMBNAIL.jpg').zero? || value.upcase.end_with?('_THUMBNAIL.JPG')
      end

      def apply_canvas_thumbnails!(manifest:, presenter:)
        sequences = manifest['sequences']
        return manifest unless sequences.is_a?(Array)

        first_sequence = sequences.first
        return manifest unless first_sequence.is_a?(Hash)

        canvases = first_sequence['canvases']
        return manifest unless canvases.is_a?(Array)

        thumbnail_urls = thumbnail_urls_by_canvas_label(work_id: presenter.id, host: presenter.hostname)
        return manifest if thumbnail_urls.empty?

        canvases.each do |canvas|
          label = canvas['label'].to_s
          thumbnail_url = thumbnail_urls[label]
          next if thumbnail_url.blank?

          canvas['thumbnail'] = [{
            '@id' => thumbnail_url,
            'id' => thumbnail_url,
            '@type' => 'dctypes:Image',
            'format' => 'image/jpeg'
          }]
        end

        manifest
      end

      def normalize_manifest_json(manifest)
        if manifest.is_a?(Hash)
          first_sequence = Array(manifest['sequences']).first
          return manifest if first_sequence.nil? || first_sequence.is_a?(Hash)

          return JSON.parse(manifest.to_json)
        end

        if manifest.respond_to?(:inner_hash)
          return JSON.parse(manifest.inner_hash.to_json)
        end

        JSON.parse(manifest.to_json)
      end

      def thumbnail_urls_by_canvas_label(work_id:, host:)
        work = find_work_by_id(work_id)
        return {} unless work && host.present?

        members = Array(work.member_ids).filter_map do |member_id|
          begin
            Hyrax.query_service.find_by(id: member_id)
          rescue Valkyrie::Persistence::ObjectNotFoundError
            nil
          end
        end

        service_by_name = members.each_with_object({}) do |member, map|
          next unless member.respond_to?(:service_file) && member.service_file

          name = member.original_file&.original_filename.to_s
          map[name] = Hyrax::Engine.routes.url_helpers.download_url(member.id, host: host) if name.present?
        end

        members.each_with_object({}) do |member, map|
          next if member.respond_to?(:service_file) && member.service_file

          source_name = member.original_file&.original_filename.to_s
          next if source_name.blank?

          thumbnail_name = generated_thumbnail_name(source_name)
          thumbnail_url = service_by_name[thumbnail_name]
          next if thumbnail_url.blank?

          map[source_name] = thumbnail_url
        end
      end
    end

    module PersistedIiifThumbnail
      include PersistedThumbnailHelpers

      def hostname
        return @hostname if instance_variable_defined?(:@hostname) && @hostname.present?
        return request.base_url if respond_to?(:request) && request
        return host_name if respond_to?(:host_name)
        return send(:base_url_for_iiif) if respond_to?(:base_url_for_iiif, true)

        'localhost'
      end

      def display_image
        image = super
        return image unless image

        IIIFManifest::DisplayImage.new(
          image.url,
          width: image.width,
          height: image.height,
          format: image.format,
          iiif_endpoint: image.iiif_endpoint,
          thumbnail: persisted_manifest_thumbnail
        )
      end

      private

      def persisted_manifest_thumbnail
        return nil if id.blank?

        host = if respond_to?(:base_url_for_iiif, true)
                 send(:base_url_for_iiif)
               elsif respond_to?(:host_name)
                 host_name
               end

        return nil if host.blank?

        persisted_url = persisted_thumbnail_service_file_url(host: host)
        return nil if persisted_url.blank?

        [{
          'id' => persisted_url,
          'type' => 'Image',
          'format' => 'image/jpeg'
        }]
      end

      def persisted_thumbnail_service_file_url(host:)
        source_file_set = find_source_file_set
        return fallback_derivative_thumbnail_url(host: host) unless source_file_set

        thumbnail_file_set = find_generated_thumbnail_file_set(source_file_set)
        return fallback_derivative_thumbnail_url(host: host) unless thumbnail_file_set

        Hyrax::Engine.routes.url_helpers.download_url(thumbnail_file_set.id, host: host)
      end

      def find_source_file_set
        Hyrax.query_service.find_by(id: id)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        nil
      end

      def find_generated_thumbnail_file_set(source_file_set)
        work = Hyrax.custom_queries.find_parent_work(resource: source_file_set)
        return nil unless work

        candidate_name = generated_thumbnail_name_for(source_file_set)
        return nil if candidate_name.blank?

        Array(work.member_ids).lazy.map do |member_id|
          Hyrax.query_service.find_by(id: member_id)
        rescue Valkyrie::Persistence::ObjectNotFoundError
          nil
        end.compact.find do |member|
          next false unless member.respond_to?(:service_file) && member.service_file

          title_match = Array(member.title).any? { |value| value.to_s == candidate_name }
          name_match = member.original_file&.original_filename.to_s == candidate_name
          title_match || name_match
        end
      end

      def generated_thumbnail_name_for(source_file_set)
        filename = source_file_set.original_file&.original_filename.to_s
        return nil if filename.blank?

        stem = File.basename(filename, File.extname(filename))
        sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
        return nil if sanitized.blank?

        "#{sanitized}_THUMBNAIL.jpg"
      end

      def fallback_derivative_thumbnail_url(host:)
        Hyrax::Engine.routes.url_helpers.download_url(id, file: 'thumbnail', host: host)
      end
    end

    module IiifV2CanvasThumbnail
      private

      def apply_record_properties
        super

        thumb = display_image&.thumbnail
        return if thumb.blank?

        canvas['thumbnail'] = thumb
      end
    end

    # ============================================================================
    # Thumbnail Path Service Patch
    # ============================================================================

    module PersistedWorkThumbnailPath
      include PersistedThumbnailHelpers

      def call(object)
        return super unless object.try(:thumbnail_id).present?

        thumb = send(:fetch_thumbnail, object)
        return super unless send(:representative_thumbnail?, thumb)

        Hyrax::Engine.routes.url_helpers.download_path(thumb.id, locale: nil)
      end
    end
  end

  # Wire IIIF manifest patches
  unless Hyrax::DisplaysImage < Scholarspace::PersistedIiifThumbnail
    Hyrax::DisplaysImage.prepend(Scholarspace::PersistedIiifThumbnail)
  end

  display_image_presenter = Hyrax::IiifManifestPresenter::DisplayImagePresenter
  unless display_image_presenter < Scholarspace::PersistedIiifThumbnail
    display_image_presenter.prepend(Scholarspace::PersistedIiifThumbnail)
  end

  canvas_builder = IIIFManifest::ManifestBuilder::CanvasBuilder
  unless canvas_builder < Scholarspace::IiifV2CanvasThumbnail
    canvas_builder.prepend(Scholarspace::IiifV2CanvasThumbnail)
  end

  unless Hyrax::ManifestBuilderService < Scholarspace::ManifestCanvasThumbnails
    Hyrax::ManifestBuilderService.prepend(Scholarspace::ManifestCanvasThumbnails)
  end

  # Wire thumbnail path service patch
  thumbnail_path_service_singleton = class << Hyrax::ThumbnailPathService
    self
  end

  unless thumbnail_path_service_singleton < Scholarspace::PersistedWorkThumbnailPath
    thumbnail_path_service_singleton.prepend(Scholarspace::PersistedWorkThumbnailPath)
  end
end
