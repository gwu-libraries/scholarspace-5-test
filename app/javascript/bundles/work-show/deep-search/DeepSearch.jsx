import React, { useState } from 'react';
import PropTypes from 'prop-types';
import * as styles from './DeepSearch.module.css';

const DeepSearch = ({ query, imageResults = [], pdfResults = [], avResults = [], currentFileId, onViewResult }) => {
  const [searchTerm, setSearchTerm] = useState(query || '');
  const [searchScope, setSearchScope] = useState('all_files');
  const [results, setResults] = useState({ query, imageResults, pdfResults, avResults });
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState('');
  const hasResults = results.imageResults.length > 0 || results.pdfResults.length > 0 || results.avResults.length > 0;
  const handleSubmit = async (event) => {
    event.preventDefault();
    const term = searchTerm.trim();
    if (!term || typeof window === 'undefined') return;

    setSearching(true);
    setError('');
    try {
      const params = new URLSearchParams({ q: term, scope: searchScope });
      if (searchScope === 'current_file' && currentFileId) params.set('file_id', currentFileId);
      const response = await fetch(`${window.location.pathname}/deep_search?${params.toString()}`, {
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) throw new Error(`Search request failed: ${response.status}`);
      setResults(await response.json());
    } catch (_error) {
      setError('Search is temporarily unavailable.');
    } finally {
      setSearching(false);
    }
  };

  const handleResultClick = (event, result) => {
    if (onViewResult?.(result)) event.preventDefault();
  };

  return (
    <section className={styles.deepSearch} aria-labelledby="deep-search-label">
      <h2 id="deep-search-label" className={styles.heading}>Deep search</h2>
      <form className={styles.searchForm} onSubmit={handleSubmit}>
        <input
          type="search"
          name="q"
          className={styles.searchInput}
          placeholder="Deep search"
          value={searchTerm}
          onChange={(event) => setSearchTerm(event.target.value)}
        />
        <select
          name="scope"
          className={styles.searchScope}
          value={searchScope}
          onChange={(event) => setSearchScope(event.target.value)}
          aria-label="Search scope"
        >
          <option value="all_images">All images</option>
          <option value="all_av">All A/V</option>
          <option value="all_pdfs">All PDFs</option>
          <option value="all_files">All files</option>
          <option value="current_file" disabled={!currentFileId}>Current file</option>
        </select>
        <button type="submit" className="btn btn-primary btn-sm" disabled={searching}>
          {searching ? 'Searching...' : 'Search'}
        </button>
      </form>

      {error && <p className={styles.noResults}>{error}</p>}

      {results.query && (
        hasResults ? (
          <div className={styles.resultStack}>
            {[
              ['In image results:', results.imageResults, 'image'],
              ['PDF result:', results.pdfResults, 'pdf'],
              [`AV result${results.avResults.length === 1 ? '' : 's'}:`, results.avResults, 'av'],
            ].map(([label, results, type]) => (
              results.length > 0 && (
                <section key={type} className={styles.resultSection}>
                  <h3>{label}</h3>
                  <ul className={styles.resultList}>
                    {results.map((result, index) => (
                      <li key={`${result.href || type}-${index}`}>
                        <a
                          href={result.href}
                          data-turbo="false"
                          data-turbolinks="false"
                          onClick={(event) => handleResultClick(event, result)}
                        >
                          {type === 'image' ? (
                            result.imageUrl ? (
                              <img src={result.imageUrl} alt={result.alt} className={styles.imageSnippet} loading="lazy" />
                            ) : (
                              <span dangerouslySetInnerHTML={{ __html: result.text }} />
                            )
                          ) : (
                            <>
                              <strong>{result.pdfLabel || result.mediaLabel}</strong>{' '}
                              {result.timestamp && <span className={styles.timestamp}>{result.timestamp}</span>}{' '}
                              <span dangerouslySetInnerHTML={{ __html: result.text }} />
                            </>
                          )}
                        </a>
                      </li>
                    ))}
                  </ul>
                </section>
              )
            ))}
          </div>
        ) : (
          <p className={styles.noResults}>No matches found for &quot;{results.query}&quot;.</p>
        )
      )}
    </section>
  );
};

DeepSearch.propTypes = {
  query: PropTypes.string,
  imageResults: PropTypes.arrayOf(PropTypes.object),
  pdfResults: PropTypes.arrayOf(PropTypes.object),
  avResults: PropTypes.arrayOf(PropTypes.object),
  currentFileId: PropTypes.string,
  onViewResult: PropTypes.func,
};

export default DeepSearch;
