# frozen_string_literal: true

class LargeFileCharacterizationService

  # FITS servlet I guess only works for files up to 2 gb?
  # There is likely a way to change that, but I can't find 
  # a simple fix. 

  # This just sets a threshold for bypassing the characterization job and presumes file types based on the extension.
  # Likely better ways to handle it, but for now with only 
  # admins depositing files, this should be sufficient

  THRESHOLD_BYTES = 1.8.gigabytes

  MIME_TYPES_BY_EXTENSION = {
    '.mov' => ['video/quicktime', 'QuickTime video'],
    '.mp4' => ['video/mp4', 'MPEG-4 video'],
    '.m4v' => ['video/x-m4v', 'MPEG-4 video'],
    '.avi' => ['video/x-msvideo', 'AVI video'],
    '.mkv' => ['video/x-matroska', 'Matroska video'],
    '.webm' => ['video/webm', 'WebM video'],
    '.mp3' => ['audio/mpeg', 'MP3 audio'],
    '.m4a' => ['audio/mp4', 'MPEG-4 audio'],
    '.wav' => ['audio/wav', 'WAVE audio'],
    '.flac' => ['audio/flac', 'FLAC audio'],
    '.pdf' => ['application/pdf', 'PDF']
  }.freeze

  class << self
    def run(metadata:, file:, user: ::User.system_user, **options)
      file_size = Array(metadata.recorded_size).first.presence&.to_i
      file_size ||= file.size.to_i if file.respond_to?(:size)
      inferred_type = MIME_TYPES_BY_EXTENSION[File.extname(metadata.original_filename.to_s).downcase]

      unless file_size && file_size > THRESHOLD_BYTES && inferred_type
        return Hyrax::Characterization::ValkyrieCharacterizationService.run(metadata: metadata, file: file, user: user, **options)
      end

      metadata.mime_type = inferred_type.first
      metadata.format_label = [inferred_type.last]
      metadata.recorded_size = [file_size.to_s]

      saved = Hyrax.persister.save(resource: metadata)
      Hyrax.publisher.publish('file.metadata.updated', metadata: saved, user: user)
      Hyrax.publisher.publish('file.characterized', file_set: Hyrax.query_service.find_by(id: saved.file_set_id), file_id: saved.id.to_s, path_hint: saved.file_identifier.to_s)
    end
  end
end