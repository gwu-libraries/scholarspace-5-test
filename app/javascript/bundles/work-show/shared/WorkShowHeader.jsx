import React from 'react';
import PropTypes from 'prop-types';
import * as styles from './WorkShowHeader.module.css';

const creatorFacetUrl = (creator) => `/catalog?f%5Bcreator_sim%5D%5B%5D=${encodeURIComponent(creator)}`;

const WorkShowHeader = ({ title, creators = [], affiliation, descriptions = [], abstracts = [] }) => (
  <header className={styles.header}>
    {affiliation && <div className={styles.affiliation}>{affiliation}</div>}
    <h1 className={styles.title}>{title}</h1>
    {creators.length > 0 && (
      <p className={styles.creators}>
        <span className={styles.label}>Creator:</span>{' '}
        {creators.map((creator, index) => (
          <React.Fragment key={creator}>
            {index > 0 && ', '}
            <a href={creatorFacetUrl(creator)}>{creator}</a>
          </React.Fragment>
        ))}
      </p>
    )}
    {descriptions.map((description, index) => (
      // eslint-disable-next-line react/no-danger
      <p key={`description-${index}`} className={styles.description}>
        <span className={styles.label}>Description:</span>{' '}
        <span dangerouslySetInnerHTML={{ __html: description }} />
      </p>
    ))}
    {abstracts.map((abstract, index) => (
      // eslint-disable-next-line react/no-danger
      <p key={`abstract-${index}`} className={styles.description}>
        <span className={styles.label}>Abstract:</span>{' '}
        <span dangerouslySetInnerHTML={{ __html: abstract }} />
      </p>
    ))}
  </header>
);

WorkShowHeader.propTypes = {
  title: PropTypes.string.isRequired,
  creators: PropTypes.arrayOf(PropTypes.string),
  affiliation: PropTypes.string,
  descriptions: PropTypes.arrayOf(PropTypes.string),
  abstracts: PropTypes.arrayOf(PropTypes.string),
};

export default WorkShowHeader;
