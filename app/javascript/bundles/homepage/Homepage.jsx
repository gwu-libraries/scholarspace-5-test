import React from 'react';
import PropTypes from 'prop-types';
import FeaturedAndRecentTabs from './components/FeaturedAndRecentTabs';
import CollectionsAndResearcherTabs from './components/CollectionsAndResearcherTabs';
import { workItemShape, collectionShape } from './components/propTypes';

const Homepage = ({
  featuredTabLabel,
  recentTabLabel,
  collectionsTabLabel,
  researcherTabLabel,
  collectionsLinkLabel,
  noFeaturedWorksText,
  noRecentWorksText,
  missingResearcherText,
  featuredWorks,
  recentDocuments,
  collections,
  collectionsUrl,
  featuredResearcherHtml,
}) => {
  return (
    <>
      <FeaturedAndRecentTabs
        featuredTabLabel={featuredTabLabel}
        recentTabLabel={recentTabLabel}
        noFeaturedWorksText={noFeaturedWorksText}
        noRecentWorksText={noRecentWorksText}
        featuredWorks={featuredWorks}
        recentDocuments={recentDocuments}
      />

      <CollectionsAndResearcherTabs
        collectionsTabLabel={collectionsTabLabel}
        researcherTabLabel={researcherTabLabel}
        collections={collections}
        collectionsUrl={collectionsUrl}
        collectionsLinkLabel={collectionsLinkLabel}
        featuredResearcherHtml={featuredResearcherHtml}
        missingResearcherText={missingResearcherText}
      />
    </>
  );
};

Homepage.propTypes = {
  featuredTabLabel: PropTypes.string.isRequired,
  recentTabLabel: PropTypes.string.isRequired,
  collectionsTabLabel: PropTypes.string.isRequired,
  researcherTabLabel: PropTypes.string.isRequired,
  collectionsLinkLabel: PropTypes.string.isRequired,
  noFeaturedWorksText: PropTypes.string.isRequired,
  noRecentWorksText: PropTypes.string.isRequired,
  missingResearcherText: PropTypes.string.isRequired,
  featuredWorks: PropTypes.arrayOf(workItemShape).isRequired,
  recentDocuments: PropTypes.arrayOf(workItemShape).isRequired,
  collections: PropTypes.arrayOf(collectionShape).isRequired,
  collectionsUrl: PropTypes.string.isRequired,
  featuredResearcherHtml: PropTypes.string,
};

Homepage.defaultProps = {
  featuredResearcherHtml: '',
};

export default Homepage;
