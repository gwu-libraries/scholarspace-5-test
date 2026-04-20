import React from 'react';
import PropTypes from 'prop-types';
import ResultList from './components/ResultList';
import CollectionsList from './components/CollectionsList';
import { workItemShape, collectionShape } from './components/propTypes';

const Homepage = ({
  recentWorksTitle,
  featuredCollectionsTitle,
  collectionsLinkLabel,
  noRecentWorksText,
  recentDocuments,
  collections,
  collectionsUrl,
}) => {
  return (
    <>
      <div className="col-sm-6 homepage-recent-works">
        <h2>{recentWorksTitle}</h2>
        <ResultList items={recentDocuments} emptyText={noRecentWorksText} />
      </div>

      <div className="col-sm-6">
        <h2>{featuredCollectionsTitle}</h2>
        <CollectionsList
          collections={collections}
          collectionsUrl={collectionsUrl}
          collectionsLinkLabel={collectionsLinkLabel}
        />
      </div>
    </>
  );
};

Homepage.propTypes = {
  recentWorksTitle: PropTypes.string.isRequired,
  featuredCollectionsTitle: PropTypes.string.isRequired,
  collectionsLinkLabel: PropTypes.string.isRequired,
  noRecentWorksText: PropTypes.string.isRequired,
  recentDocuments: PropTypes.arrayOf(workItemShape).isRequired,
  collections: PropTypes.arrayOf(collectionShape).isRequired,
  collectionsUrl: PropTypes.string.isRequired,
};

export default Homepage;
