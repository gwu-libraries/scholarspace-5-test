# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::OrchestrateJob do
  subject(:job) { described_class.new }

  def build_source_file_set(id:, filename:, mime_type:)
    original_file = instance_double('OriginalFile', mime_type: mime_type, original_filename: filename)

    double(
      'FileSet',
      id: id,
      original_file: original_file,
      audio?: mime_type.to_s.start_with?('audio/'),
      video?: mime_type.to_s.start_with?('video/'),
      pdf?: mime_type == 'application/pdf',
      image?: mime_type.to_s.start_with?('image/')
    )
  end

  describe '#ensure_default_representative_selection' do
    it 'delegates representative selection to Derivatives::WorkLevel::RepresentativeSelector' do
      work = instance_double('Work')
      selector = instance_double(Derivatives::WorkLevel::RepresentativeSelector, call: work)

      job.instance_variable_set(:@work, work)
      allow(Derivatives::WorkLevel::RepresentativeSelector).to receive(:new).with(work: work).and_return(selector)

      job.send(:ensure_default_representative_selection)

      expect(selector).to have_received(:call)
      expect(job.instance_variable_get(:@work)).to eq(work)
    end
  end

  describe '#schedule_derivatives_jobs' do
    it 'reschedules orchestration while original files are not characterized' do
      uncharacterized_source_file = build_source_file_set(
        id: 'image-1',
        filename: 'page.tif',
        mime_type: nil
      )
      work = instance_double('Work', id: 'work-not-ready', original_member_file_sets: [uncharacterized_source_file])

      job.instance_variable_set(:@work, work)

      allow(job).to receive(:reschedule_for_readiness)
      allow(job).to receive(:ensure_default_representative_selection)
      allow(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).to receive(:perform_later)

      job.send(:schedule_derivatives_jobs, work_id: 'work-not-ready', retries: 3)

      expect(job).to have_received(:reschedule_for_readiness).with(work_id: 'work-not-ready', retries: 3)
      expect(job).not_to have_received(:ensure_default_representative_selection)
      expect(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).not_to have_received(:perform_later)
    end

    it 'skips custom derivative jobs for unsupported source files' do
      unsupported_source_file = build_source_file_set(
        id: 'doc-1',
        filename: 'document.docx',
        mime_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      work = instance_double('Work', id: 'work-unsupported', original_member_file_sets: [unsupported_source_file])

      job.instance_variable_set(:@work, work)

      allow(job).to receive(:files_ready_for_derivatives?).and_return(true)
      allow(job).to receive(:ensure_default_representative_selection)
      allow(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob).to receive(:set).and_return(double(perform_later: true))
      allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualGenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfGenerateJob).to receive(:perform_later)

      job.send(:schedule_derivatives_jobs, work_id: 'work-unsupported', retries: 1)

      expect(job).not_to have_received(:ensure_default_representative_selection)
      expect(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).not_to have_received(:perform_later)
      expect(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob).not_to have_received(:perform_later)
      expect(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualGenerateJob).not_to have_received(:perform_later)
      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob).not_to have_received(:perform_later)
      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfGenerateJob).not_to have_received(:perform_later)
    end

    it 'enqueues thumbnail, image PDF orchestration, and image presentation jobs for source images' do
      image_source_file = build_source_file_set(
        id: 'image-1',
        filename: 'page.tif',
        mime_type: 'image/tiff'
      )
      work = instance_double('Work', id: 'work-image', original_member_file_sets: [image_source_file])

      job.instance_variable_set(:@work, work)

      delayed_representative_job = double('RepresentativeThumbnailDelayedJob', perform_later: true)

      allow(job).to receive(:files_ready_for_derivatives?).and_return(true)
      allow(job).to receive(:ensure_default_representative_selection)
      allow(job).to receive(:thumbnail_source_file_set_ids).and_return(['image-1'])
      image_presentation = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromImage, source_file_set_ids: ['image-1'])
      allow(Derivatives::FileSetLevel::PresentationVersion::FromImage).to receive(:new).with(work).and_return(image_presentation)

      allow(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob).to receive(:set).with(wait: described_class::REPRESENTATIVE_THUMBNAIL_WAIT).and_return(delayed_representative_job)
      allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromImageGenerateJob).to receive(:perform_later)

      job.send(:schedule_derivatives_jobs, work_id: 'work-image', retries: 1)

      expect(job).to have_received(:ensure_default_representative_selection)
      expect(DerivativeJobs::FileSetLevel::Thumbnail::GenerateJob).to have_received(:perform_later).with(
        work_id: 'work-image',
        source_file_set_id: 'image-1'
      )
      expect(delayed_representative_job).to have_received(:perform_later).with(work_id: 'work-image')
      expect(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob).to have_received(:perform_later).with(work_id: 'work-image')
      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromImageGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-image',
        source_file_set_id: 'image-1'
      )
    end

    it 'enqueues per-source PDF text extraction for source PDFs' do
      pdf_source_file = build_source_file_set(
        id: 'pdf-1',
        filename: 'source.pdf',
        mime_type: 'application/pdf'
      )
      work = instance_double('Work', id: 'work-pdf', original_member_file_sets: [pdf_source_file])
      extraction_service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromPdf)

      job.instance_variable_set(:@work, work)

      allow(job).to receive(:files_ready_for_derivatives?).and_return(true)
      allow(job).to receive(:ensure_default_representative_selection)
      allow(job).to receive(:thumbnail_source_file_set_ids).and_return([])
      allow(Derivatives::FileSetLevel::TextExtraction::FromPdf).to receive(:new).with(work).and_return(extraction_service)
      allow(extraction_service).to receive(:pending_source_pdf_file_set_ids).and_return(['pdf-1'])

      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfGenerateJob).to receive(:perform_later)

      job.send(:schedule_derivatives_jobs, work_id: 'work-pdf', retries: 1)

      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-pdf',
        pdf_file_set_id: 'pdf-1'
      )
      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfGenerateJob).not_to have_received(:perform_later)
    end

    it 'enqueues transcript and audio visual presentation jobs for octet-stream videos with mp4 filenames' do
      video_source_file = build_source_file_set(
        id: 'video-1',
        filename: 'lecture.mp4',
        mime_type: 'application/octet-stream'
      )
      work = instance_double('Work', id: 'work-video', original_member_file_sets: [video_source_file])
      transcript_entrypoint = instance_double(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual, source_file_set_ids: ['video-1'])

      job.instance_variable_set(:@work, work)

      allow(job).to receive(:files_ready_for_derivatives?).and_return(true)
      allow(job).to receive(:ensure_default_representative_selection)
      allow(job).to receive(:thumbnail_source_file_set_ids).and_return([])
      allow(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual).to receive(:new).with(work).and_return(transcript_entrypoint)
      audio_visual_presentation = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual, source_file_set_ids: ['video-1'])
      allow(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual).to receive(:new).with(work).and_return(audio_visual_presentation)

      allow(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualGenerateJob).to receive(:perform_later)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualGenerateJob).to receive(:perform_later)

      job.send(:schedule_derivatives_jobs, work_id: 'work-video', retries: 1)

      expect(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-video',
        source_file_set_id: 'video-1'
      )
      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-video',
        source_file_set_id: 'video-1'
      )
    end
  end


end
