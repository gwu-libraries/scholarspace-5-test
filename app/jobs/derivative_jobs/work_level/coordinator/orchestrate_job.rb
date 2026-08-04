# frozen_string_literal: true

class DerivativeJobs::WorkLevel::Coordinator::OrchestrateJob < ApplicationJob
  include Constants::MimeTypeConstants
  include Derivatives::Concerns::SourceFileSetMimeDetection
  include JobDistributedLock

  # For simplicity sake, we are waiting until all of the filesets attach to a work have been characterized prior to
  # generating any of these scholarspace derivatives - as some require processing files from multiple filesets.

  READINESS_RETRY_MAX = 10
  READINESS_RETRY_STEP_SECONDS = 60
  READINESS_RETRY_MAX_WAIT_SECONDS = 10.minutes.to_i

  def perform(work_id:, retries: 0)
    next_retry = retries.to_i + 1

    with_work(work_id: work_id) do |work|
      @work = work
      schedule_derivatives_jobs(work_id: work_id, retries: next_retry)
    end
  end

  def file_types
    @file_types ||= @work.original_member_file_sets
                    .filter_map { |file_set| file_set.original_file&.mime_type }
                    .uniq
  end

  def has_supported_derivative_source_files?
    @work.original_member_file_sets.any? do |file_set|
      source_image_file_set?(file_set) || source_av_file_set?(file_set) || source_pdf_file_set?(file_set)
    end
  end

  def has_pdf_source_files?
    @has_pdf_source_files ||= @work.original_member_file_sets.any? { |file_set| source_pdf_file_set?(file_set) }
  end

  def has_image_source_files?
    @has_image_source_files ||= @work.original_member_file_sets.any? { |file_set| source_image_file_set?(file_set) }
  end

  def has_video_source_files?
    @has_video_source_files ||= @work.original_member_file_sets.any? { |file_set| source_video_file_set?(file_set) }
  end

  def has_av_source_files?
    @has_av_source_files ||= @work.original_member_file_sets.any? { |file_set| source_av_file_set?(file_set) }
  end

  # check if every file in the work has been characterized
  def files_ready_for_derivatives?
    @work.original_member_file_sets.all? { |file_set| file_set.original_file&.mime_type.present? }
  end

  def schedule_derivatives_jobs(work_id:, retries:)
    unless files_ready_for_derivatives?
      reschedule_for_readiness(work_id: work_id, retries: retries)
      return
    end

    return unless has_supported_derivative_source_files?

    ensure_default_representative_selection

    # generate thumbnails per source file set, then finalize representative thumbnail
    if has_image_source_files? || has_video_source_files? || has_pdf_source_files?
      thumbnail_source_file_set_ids.each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob.perform_later(
          work_id: @work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end

      DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob.set(wait: 2.minutes).perform_later(work_id: @work.id.to_s) if thumbnail_source_file_set_ids.any?
    end

    # if a collection of images, generate a pdf
    if has_image_source_files?
      DerivativeJobs::WorkLevel::ImagesToPdf::OrchestrateJob.perform_later(work_id: @work.id.to_s)

      Derivatives::FileSetLevel::PresentationVersion.source_image_file_set_ids(@work).each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::PresentationVersion::ImageGenerateJob.perform_later(
          work_id: @work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end
    end

    # if a/v, generate a transcript
    if has_av_source_files?
      Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVideo
        .new(@work)
        .source_file_set_ids
        .each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob.perform_later(
          work_id: @work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end

      Derivatives::FileSetLevel::PresentationVersion.source_av_file_set_ids(@work).each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::PresentationVersion::AvGenerateJob.perform_later(
          work_id: @work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end
    end

    # if a pdf source file is present, run OCR to produce hOCR for full-text search and text overlay
    # This is ALWAYS done regardless of preferences
    if has_pdf_source_files?
      Derivatives::FileSetLevel::TextExtraction::FromPdf.new(@work).pending_source_pdf_file_set_ids.each do |pdf_file_set_id|
        DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob.perform_later(
          work_id: @work.id.to_s,
          pdf_file_set_id: pdf_file_set_id
        )
      end

      Derivatives::FileSetLevel::PresentationVersion.source_pdf_file_set_ids(@work).each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::PresentationVersion::PdfGenerateJob.perform_later(
          work_id: @work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end
    end
  end

  def reschedule_for_readiness(work_id:, retries:)
    wait_seconds = linear_retry_wait_seconds(
      retries: retries,
      step_seconds: READINESS_RETRY_STEP_SECONDS,
      max_seconds: READINESS_RETRY_MAX_WAIT_SECONDS
    )

    reschedule_with_retry(
      job_class: self.class,
      args: { work_id: work_id },
      retries: retries,
      retry_max: READINESS_RETRY_MAX,
      wait_seconds: wait_seconds
    )
  end

  def ensure_default_representative_selection
    @work = Derivatives::WorkLevel::RepresentativeSelector.new(work: @work).call
  end

  def thumbnail_source_file_set_ids
    @thumbnail_source_file_set_ids ||= Array(@work.original_member_file_sets)
                                     .select { |file_set| Derivatives::FileSetLevel::ThumbnailGeneration::Thumbnail.thumbnail_supported_file_set?(file_set) }
                                     .map { |file_set| file_set.id.to_s }
  end

  def supported_derivative_source_file_type?(mime_type)
    mime_type.start_with?(*SUPPORTED_DERIVATIVE_SOURCE_MIME_PREFIXES) || mime_type == PDF_MIME_TYPE
  end

  protected

  def lock_key_for(arguments)
    # Serialize coordinator to prevent multiple DerivativeJobs::WorkLevel::Coordinator::OrchestrateJob from enqueueing
    # conflicting child jobs simultaneously on the same work
    "derivatives:coordinator:work:#{arguments[:work_id]}"
  end
end
