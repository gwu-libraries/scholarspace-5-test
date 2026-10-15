# Models

The application defines four work types. Each is a Hyrax work with shared basic metadata and a schema for fields specific to that type:

- `ETD` — an electronic thesis or dissertation, with fields for details such as degree, advisors, GW unit, and committee members.
- `JournalIssue` — a journal issue deposited as a single work, even when it contains multiple pieces.
- `AcademicDocument` — a non-ETD scholarly work, such as an undergraduate research-competition submission.
- `ArchivalDocument` — material managed by Special Collections, such as a digitized archival document.

The work models also include shared concerns for representative thumbnails and queries about member file sets. `FileSet` extends Hyrax's file-set model with file-type detection and those shared concerns. Collections use Hyrax's collection model and `CollectionResource`.