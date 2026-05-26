import React from 'react';
import PropTypes from 'prop-types';
import { workItemShape } from './prop-types';

const ResultList = ({ items, emptyText }) => {
  if (items.length === 0) return <p>{emptyText}</p>;

  return (
    <ol className="homepage-work-list">
      {items.map((item) => (
        <li key={item.id} className="homepage-work-list-item">
          <div className="recent-work-card">
            {item.thumbnailUrl && (
              <a href={item.url} className="recent-work-card-thumbnail-link">
                <img src={item.thumbnailUrl} alt="" width="90" />
              </a>
            )}
            <div className="recent-work-card-body">
              <h3>
                <a href={item.url}>{item.title}</a>
              </h3>
              {item.depositor && <p><strong>Depositor:</strong> {item.depositor}</p>}
              {item.keywords.length > 0 && (
                <p>
                  <strong>Keywords:</strong>{' '}
                  {item.keywords.map((keyword, index) => (
                    <React.Fragment key={`${item.id}-${keyword.label}`}>
                      {index > 0 && ', '}
                      <a href={keyword.url}>{keyword.label}</a>
                    </React.Fragment>
                  ))}
                </p>
              )}
            </div>
          </div>
        </li>
      ))}
    </ol>
  );
};

ResultList.propTypes = {
  items: PropTypes.arrayOf(workItemShape).isRequired,
  emptyText: PropTypes.string.isRequired,
};

export default ResultList;
