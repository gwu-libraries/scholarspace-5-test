import React, { useState } from 'react';
import PropTypes from 'prop-types';
import ResultList from './ResultList';
import { workItemShape } from './propTypes';

const FeaturedAndRecentTabs = ({
  featuredTabLabel,
  recentTabLabel,
  noFeaturedWorksText,
  noRecentWorksText,
  featuredWorks,
  recentDocuments,
}) => {
  const [activeTab, setActiveTab] = useState('featured');

  return (
    <div className="col-sm-6">
      <div role="tablist" aria-label="Featured and recent works" className="nav nav-tabs">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'featured'}
          className={`nav-link ${activeTab === 'featured' ? 'active' : ''}`}
          onClick={() => setActiveTab('featured')}
        >
          {featuredTabLabel}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'recent'}
          className={`nav-link ${activeTab === 'recent' ? 'active' : ''}`}
          onClick={() => setActiveTab('recent')}
        >
          {recentTabLabel}
        </button>
      </div>

      {activeTab === 'featured' && <ResultList items={featuredWorks} emptyText={noFeaturedWorksText} />}
      {activeTab === 'recent' && <ResultList items={recentDocuments} emptyText={noRecentWorksText} />}
    </div>
  );
};

FeaturedAndRecentTabs.propTypes = {
  featuredTabLabel: PropTypes.string.isRequired,
  recentTabLabel: PropTypes.string.isRequired,
  noFeaturedWorksText: PropTypes.string.isRequired,
  noRecentWorksText: PropTypes.string.isRequired,
  featuredWorks: PropTypes.arrayOf(workItemShape).isRequired,
  recentDocuments: PropTypes.arrayOf(workItemShape).isRequired,
};

export default FeaturedAndRecentTabs;
