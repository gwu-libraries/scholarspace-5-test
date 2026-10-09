## Indexers

Indexers build the Solr documents used to search and display file sets, works, and collections. Custom indexers are organized by resource level under `file_set_level/`, `work_level/`, and `collection_level/`.

### File sets

`FileSetIndexer` starts with Hyrax's file-set metadata and adds the parent work ID, when available, plus searchable text from supported primary files. It extracts PDF text with `pdftotext`, extracts text from HOCR, and removes WebVTT formatting and timestamps. HOCR markup is also stored for search highlighting. OCR and transcript generation happen outside this indexer; it indexes those files when they are available.

### Works

The work indexers share a common pattern across academic documents, archival documents, ETDs, and journal issues. In addition to Hyrax metadata indexing, they aggregate indexed text from member file sets so a work can appear in search results for content in its files. Shared concerns also add a contributor facet value and index the earliest year found in `date_created`.

### Collections

`CollectionResourceIndexer` uses Hyrax's standard basic-metadata and collection-resource indexers. There is currently no additional collection-specific indexing logic in this application.