import React from 'react';
import PropTypes from 'prop-types';
import { collectionShape } from './prop-types';

const CollectionsList = ({ collections, collectionsUrl, collectionsLinkLabel }) => (
  <>
    <ul>
      {collections.map((collection) => (
        <li key={collection.id}>
          {collection.thumbnailUrl && (
            <a href={collection.url}>
              <img src={collection.thumbnailUrl} alt="" width="90" />
            </a>
          )}
          <a href={collection.url}>{collection.title}</a>
        </li>
      ))}
    </ul>
    <p>
      <a href={collectionsUrl}>{collectionsLinkLabel}</a>
    </p>
  </>
);

CollectionsList.propTypes = {
  collections: PropTypes.arrayOf(collectionShape).isRequired,
  collectionsUrl: PropTypes.string.isRequired,
  collectionsLinkLabel: PropTypes.string.isRequired,
};

export default CollectionsList;
