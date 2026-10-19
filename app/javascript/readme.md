# Custom JavaScript

The custom JavaScript uses React and React on Rails to add interactive features to work show pages. The server renders the page and provides the work data; the React work-show bundle presents the metadata, files, viewers, and search tools.

## Catalog

`packs/catalog-bundler.js` is the Shakapacker entry point for the catalog page
bundle, implemented in `bundles/catalog/`. It initializes the Blacklight range
chart on catalog pages using Blacklight's page-load handler, including
Turbolinks navigation. The Date Created filter uses the earliest indexed
creation year and provides a distribution chart and Begin/End year inputs. When
all results share one year, the plugin shows the inputs without a chart. A
chart is drawn when the distribution has multiple year buckets. Its JavaScript
package version matches the `blacklight_range_limit` gem.

The range form validates that Begin is no later than End, displaying an inline
message and blocking submission until corrected. Equal years and open-ended
ranges are allowed. Server-side validation also rejects reversed, non-integer,
or out-of-bounds years: catalog requests return to the search with an alert and
only the invalid range removed; invalid distribution requests return HTTP 422.

## Work show

The bundle entry point is `packs/work-show-bundler.js`. It registers the `WorkShow` component with React on Rails. `bundles/work-show/WorkShow.jsx` coordinates the page: it displays the work header, metadata, file panel, deep search, and the active viewer. Viewer and file-panel code is loaded as needed, with additional deferral for works with many files.

The main areas under `bundles/work-show/` are:

- `shared/` — page-wide sections shared by the work-show layout, including the header, metadata, and collapsible sections.
- `file-panel/` — original and service file lists, with actions to open supported files in a viewer.
- `deep-search/` — searches within a work's files and can navigate from a result to the relevant viewer location.
- `viewers/` — viewer implementations and rendering helpers:
  - `clover/` displays image-based IIIF content.
  - `pdfjs/` displays PDFs.
  - `ramp/` displays audiovisual IIIF content and transcripts.
  - `rendering.jsx` selects and renders the active viewer.

File classification and grouping logic lives in `file-panel/grouping.js` beside
the file-panel components that consume it.

The viewer mode can be selected from the file panel or from a deep-search result. Work-show data, including metadata, file members, viewer manifests, and search results, is passed to `WorkShow` as props.

When a generated reading-mode PDF is attached, the Images group offers "View in
reading mode" to regular and anonymous users as well as administrators. Its PDF
and hOCR URLs are supplied separately in the `readingModePdf` prop, independently
of the admin-only service-file list. Downloads retain their existing access
controls; works without a reading-mode PDF do not show the action.