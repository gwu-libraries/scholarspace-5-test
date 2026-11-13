import React from 'react';
import PropTypes from 'prop-types';
import CollapsibleSection from './CollapsibleSection';
import * as styles from './WorkShowMetadata.module.css';

const FACET_FIELDS = {
  based_near_label_tesim: 'based_near_label_sim',
  contributor_tesim: 'contributor_sim',
  creator_tesim: 'creator_sim',
  advisor_tesim: 'contributor_sim',
  committee_member_tesim: 'contributor_sim',
  file_format_tesim: 'file_format_sim',
  gw_affiliation_tesim: 'gw_affiliation_sim',
  human_readable_type_tesim: 'human_readable_type_sim',
  keyword_tesim: 'keyword_sim',
  language_tesim: 'language_sim',
  publisher_tesim: 'publisher_sim',
  resource_type_tesim: 'resource_type_sim',
  subject_tesim: 'subject_sim',
  format_tesim: 'file_format_sim',
};

const facetUrl = (facet, value) => `/catalog?f%5B${encodeURIComponent(facet)}%5D%5B%5D=${encodeURIComponent(value)}`;

const MetadataValue = ({ fieldName, value }) => {
  const facet = FACET_FIELDS[fieldName];

  if (!facet) {
    // eslint-disable-next-line react/no-danger
    return <span dangerouslySetInnerHTML={{ __html: value }} />;
  }

  return (
    <a href={facetUrl(facet, value)}>
      {/* eslint-disable-next-line react/no-danger */}
      <span dangerouslySetInnerHTML={{ __html: value }} />
    </a>
  );
};

MetadataValue.propTypes = {
  fieldName: PropTypes.string.isRequired,
  value: PropTypes.string.isRequired,
};

const WorkShowMetadata = ({ metadata = [] }) => {
  if (!metadata.length) return null;

  return (
    <CollapsibleSection title="Metadata and descriptions">
      <div className={styles.metadata}>
        <dl className={styles.list}>
          {metadata.map((field) => (
            <React.Fragment key={field.name}>
              <dt>{field.label}</dt>
              <dd>
                {field.values.map((value, index) => (
                  <div key={`${field.name}-${index}`}>
                    <MetadataValue fieldName={field.name} value={value} />
                  </div>
                ))}
              </dd>
            </React.Fragment>
          ))}
        </dl>
      </div>
    </CollapsibleSection>
  );
};

WorkShowMetadata.propTypes = {
  metadata: PropTypes.arrayOf(PropTypes.shape({
    name: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    values: PropTypes.arrayOf(PropTypes.string).isRequired,
  })),
};

export default WorkShowMetadata;
