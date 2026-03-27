import React, { useState } from 'react';
import PropTypes from 'prop-types';
import CollectionsList from './CollectionsList';
import { collectionShape } from './propTypes';

const CollectionsAndResearcherTabs = ({
  collectionsTabLabel,
  researcherTabLabel,
  collections,
  collectionsUrl,
  collectionsLinkLabel,
  featuredResearcherHtml,
  missingResearcherText,
}) => {
  const [activeTab, setActiveTab] = useState('collections');
  const hasResearcher = featuredResearcherHtml && featuredResearcherHtml.trim().length > 0;

  return (
    <div className="col-sm-6">
      <div role="tablist" aria-label="Collections and researcher" className="nav nav-tabs">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'collections'}
          className={`nav-link ${activeTab === 'collections' ? 'active' : ''}`}
          onClick={() => setActiveTab('collections')}
        >
          {collectionsTabLabel}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'researcher'}
          className={`nav-link ${activeTab === 'researcher' ? 'active' : ''}`}
          onClick={() => setActiveTab('researcher')}
        >
          {researcherTabLabel}
        </button>
      </div>

      {activeTab === 'collections' && (
        <CollectionsList
          collections={collections}
          collectionsUrl={collectionsUrl}
          collectionsLinkLabel={collectionsLinkLabel}
        />
      )}

      {activeTab === 'researcher' && (
        hasResearcher
          ? <div dangerouslySetInnerHTML={{ __html: featuredResearcherHtml }} />
          : <p>{missingResearcherText}</p>
      )}
    </div>
  );
};

CollectionsAndResearcherTabs.propTypes = {
  collectionsTabLabel: PropTypes.string.isRequired,
  researcherTabLabel: PropTypes.string.isRequired,
  collections: PropTypes.arrayOf(collectionShape).isRequired,
  collectionsUrl: PropTypes.string.isRequired,
  collectionsLinkLabel: PropTypes.string.isRequired,
  featuredResearcherHtml: PropTypes.string,
  missingResearcherText: PropTypes.string.isRequired,
};

CollectionsAndResearcherTabs.defaultProps = {
  featuredResearcherHtml: '',
};

export default CollectionsAndResearcherTabs;
