import React, { useState } from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { groupOriginalMembers } from '../utils';
import * as styles from './FilePanel.module.css';

const MEMBERS_PER_PAGE = 10;

const FilePanelOriginalTab = ({ members, onViewMember, onViewReadingMode }) => {
  const [pageByGroupLabel, setPageByGroupLabel] = useState({});

  if (members.length === 0) return <p>No original files are attached to this work.</p>;

  const groups = groupOriginalMembers(members);

  const pageForGroup = (groupLabel) => {
    const page = Number(pageByGroupLabel[groupLabel] || 1);
    return Number.isFinite(page) && page > 0 ? page : 1;
  };

  const updateGroupPage = (groupLabel, page) => {
    setPageByGroupLabel((previous) => ({
      ...previous,
      [groupLabel]: page,
    }));
  };

  return (
    <>
      {groups.map((group) => {
        const currentPage = pageForGroup(group.label);
        const totalPages = Math.max(1, Math.ceil(group.members.length / MEMBERS_PER_PAGE));
        const safePage = Math.min(currentPage, totalPages);
        const startIndex = (safePage - 1) * MEMBERS_PER_PAGE;
        const endIndex = startIndex + MEMBERS_PER_PAGE;
        const pagedMembers = group.members.slice(startIndex, endIndex);
        const canGoPrevious = safePage > 1;
        const canGoNext = safePage < totalPages;

        return (
          <FilePanelGroup
            key={group.label}
            label={group.label}
            count={group.members.length}
            defaultOpen={false}
          >
            {group.label === 'Images' && onViewReadingMode && (
              <div className={styles.groupInlineAction}>
                <button
                  type="button"
                  className={`btn btn-sm btn-default ${styles.readingModeButton}`}
                  onClick={onViewReadingMode}
                >
                  View in reading mode
                </button>
              </div>
            )}

            <FilePanelTable
              members={pagedMembers}
              onViewMember={onViewMember}
            />

            {totalPages > 1 && (
              <div className="clearfix" style={{ marginTop: '8px' }}>
                <div className="btn-group" role="group" aria-label={`${group.label} pagination`}>
                  <button
                    type="button"
                    className="btn btn-default btn-xs"
                    disabled={!canGoPrevious}
                    onClick={() => updateGroupPage(group.label, safePage - 1)}
                  >
                    Previous
                  </button>
                  <button
                    type="button"
                    className="btn btn-default btn-xs"
                    disabled={!canGoNext}
                    onClick={() => updateGroupPage(group.label, safePage + 1)}
                  >
                    Next
                  </button>
                </div>
                <span className="pull-right" style={{ lineHeight: '24px' }}>
                  Page {safePage} of {totalPages}
                </span>
              </div>
            )}
          </FilePanelGroup>
        );
      })}
    </>
  );
};

FilePanelOriginalTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onViewMember: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

FilePanelOriginalTab.defaultProps = {
  onViewMember: undefined,
  onViewReadingMode: undefined,
};

export default FilePanelOriginalTab;
