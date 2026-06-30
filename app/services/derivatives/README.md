# Derivatives Service Map

This directory contains derivative-generation services grouped by pipeline responsibility.

## Work Level

- `work_level/pdf_generation/from_images.rb`
  - Joined PDF assembly for source images.
- `work_level/representative_selector.rb`
  - Work representative selection flow.
- `work_level/thumbnail_generation/thumbnail.rb`
  - Work-level thumbnail orchestration and representative selection.

## File Set Level

- `file_set_level/presentation_version.rb`
  - Generates and persists presentation-version media derivatives for AV and images.
- `file_set_level/text_extraction/from_pdf.rb`
  - Text extraction and OCR implementation for source PDFs.
- `file_set_level/text_extraction/from_images.rb`
  - Text extraction and page/joined hOCR implementation for source images.
- `file_set_level/transcript_extraction/from_audio_video.rb`
  - Transcript extraction and persistence implementation for source audio/video files.
- `file_set_level/thumbnail_generation/`
  - `base.rb`
    - Shared thumbnail command and file handling helpers.
  - `from_image.rb`
    - Image thumbnail generation.
  - `from_pdf.rb`
    - PDF thumbnail generation.
  - `from_av.rb`
    - Audio/video thumbnail generation.

## Shared Helpers

- `concerns/`
  - Reusable generation/attach/cache/locking helpers shared across pipelines.
- `../derivative_cache_service.rb`
  - Cross-job cache handoff for generated derivative artifacts.
- `../derivative_link_resolver.rb`
  - Resolves source/derivative linkage metadata.
