# Jobs

Custom derivative jobs coordinate asynchronous processing after ingest. The Hyrax listener schedules work-level orchestration once a work is created or updated. 

Orchestration waits until member files are characterized, then enqueues work for supported sources: images can produce thumbnails, presentation versions, and a reading-mode PDF with OCR text; PDFs produce OCR text; audio and video can produce transcripts and presentation versions.

Jobs are organized by resource level and derivative type under `derivative_jobs/`. 

Generation jobs create outputs in the derivative cache, then enqueue persist jobs to attach or replace service files and reindex affected resources. Work-level jobs coordinate outputs that depend on multiple file sets. Queue and retry timing is configured through `DerivativeJobSettings`; distributed locks prevent duplicate work from conflicting.
