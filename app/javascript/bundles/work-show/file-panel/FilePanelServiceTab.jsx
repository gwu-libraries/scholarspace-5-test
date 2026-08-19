import React from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { isAvMember, isImageMember } from '../utils';
import * as styles from './FilePanel.module.css';

const normalizeLabel = (value) => {
  const label = (value || '').trim();
  return label.length > 0 ? label : 'Untitled File';
};

const byLabel = (a, b) => normalizeLabel(a?.label).localeCompare(normalizeLabel(b?.label));

const originalTypeLabel = (member) => {
  if (!member) return 'Other';
  if (isAvMember(member)) return 'Audio / Video';
  if (member.isPdf) return 'PDFs';
  if (isImageMember(member)) return 'Images';
  return 'Other';
};

const typeSortOrder = ['Audio / Video', 'PDFs', 'Images', 'Other'];
const READING_MODE_GROUP_ID = '__reading_mode_pdf__';

const readingModeMember = (member) => {
  const label = (member?.label || '').toLowerCase();
  return label.startsWith('reading_mode_pdf') || label.startsWith('reading_mode_hocr');
};

const hocrSiblingForPdf = (pdfMember, members) => {
  if (!pdfMember?.hocrUrl) return null;

  return members.find((member) => (
    member.id !== pdfMember.id
      && member.downloadUrl
      && member.downloadUrl === pdfMember.hocrUrl
  )) || null;
};

const FilePanelServiceTab = ({ members, originalMembers, onViewReadingMode }) => {
  if (members.length === 0) return <p>No service files are attached to this work.</p>;

  const representativeThumbnailMembers = members.filter((member) => Boolean(member?.isRepresentativeThumbnail));
  const nonRepresentativeMembers = members.filter((member) => !member?.isRepresentativeThumbnail);
  const readingModePdfMember = nonRepresentativeMembers.find((member) => member.isReadingModePdf);
  const readingModeHocrMember = hocrSiblingForPdf(readingModePdfMember, nonRepresentativeMembers);
  const standaloneMemberIds = new Set([
    ...representativeThumbnailMembers.map((member) => member.id),
    readingModePdfMember?.id,
    readingModeHocrMember?.id,
  ].filter(Boolean));

  const groupedCandidates = members.filter((member) => !standaloneMemberIds.has(member.id));
  const readingModeMembersFromFilename = groupedCandidates.filter((member) => readingModeMember(member)).sort(byLabel);
  const nonReadingModeGroupedCandidates = groupedCandidates.filter((member) => !readingModeMember(member));

  const originalById = new Map(
    originalMembers.map((member) => [String(member.id), member]),
  );

  const linkedBySourceId = new Map();
  const unlinkedMembers = [];

  nonReadingModeGroupedCandidates.forEach((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();

    if (!sourceId || !originalById.has(sourceId)) {
      unlinkedMembers.push(member);
      return;
    }

    if (!linkedBySourceId.has(sourceId)) linkedBySourceId.set(sourceId, []);
    linkedBySourceId.get(sourceId).push(member);
  });

  const sourceGroups = Array.from(linkedBySourceId.entries())
    .map(([sourceId, serviceSiblings]) => {
      const original = originalById.get(sourceId);
      return {
        sourceId,
        sourceLabel: normalizeLabel(original?.label),
        typeLabel: originalTypeLabel(original),
        members: [...serviceSiblings].sort(byLabel),
      };
    })
    .sort((a, b) => a.sourceLabel.localeCompare(b.sourceLabel));

  const groupedByType = sourceGroups.reduce((map, group) => {
    if (!map.has(group.typeLabel)) map.set(group.typeLabel, []);
    map.get(group.typeLabel).push(group);
    return map;
  }, new Map());

  const readingModeMembers = [
    readingModePdfMember,
    readingModeHocrMember,
    ...readingModeMembersFromFilename,
  ].filter(Boolean);

  const uniqueReadingModeMembers = Array.from(
    new Map(readingModeMembers.map((member) => [member.id, member])).values(),
  ).sort(byLabel);

  if (uniqueReadingModeMembers.length > 0) {
    if (!groupedByType.has('Images')) groupedByType.set('Images', []);

    groupedByType.get('Images').unshift({
      sourceId: READING_MODE_GROUP_ID,
      sourceLabel: 'Reading Mode PDF',
      typeLabel: 'Images',
      members: uniqueReadingModeMembers,
    });
  }

  const typeGroups = Array.from(groupedByType.entries())
    .map(([typeLabel, sourceFileGroups]) => ({
      typeLabel,
      sourceFileGroups,
      groupCount: sourceFileGroups.length,
    }))
    .sort((a, b) => typeSortOrder.indexOf(a.typeLabel) - typeSortOrder.indexOf(b.typeLabel));

  const sortedUnlinkedMembers = [...unlinkedMembers].sort(byLabel);

  return (
    <>
      {representativeThumbnailMembers.length > 0 && (
        <FilePanelGroup label="Representative Thumbnail" count={representativeThumbnailMembers.length} defaultOpen={false}>
          <FilePanelTable showViewColumn={false} members={representativeThumbnailMembers} />
        </FilePanelGroup>
      )}
      {typeGroups.map((typeGroup) => (
        <FilePanelGroup
          key={typeGroup.typeLabel}
          label={typeGroup.typeLabel}
          count={typeGroup.groupCount}
          defaultOpen={false}
        >
          {typeGroup.sourceFileGroups.map((sourceGroup) => (
            <FilePanelGroup
              key={sourceGroup.sourceId}
              label={sourceGroup.sourceLabel}
              count={sourceGroup.members.length}
              defaultOpen={sourceGroup.sourceId === READING_MODE_GROUP_ID ? true : false}
            >
              {sourceGroup.sourceId === READING_MODE_GROUP_ID && onViewReadingMode && (
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
              <FilePanelTable showViewColumn={false} members={sourceGroup.members} />
            </FilePanelGroup>
          ))}
        </FilePanelGroup>
      ))}
      {sortedUnlinkedMembers.length > 0 && (
        <FilePanelGroup label="Unlinked Service Files" count={sortedUnlinkedMembers.length} defaultOpen={false}>
          <FilePanelTable showViewColumn={false} members={sortedUnlinkedMembers} />
        </FilePanelGroup>
      )}
    </>
  );
};

FilePanelServiceTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  originalMembers: PropTypes.arrayOf(PropTypes.object),
  onViewReadingMode: PropTypes.func,
};

FilePanelServiceTab.defaultProps = {
  originalMembers: [],
  onViewReadingMode: undefined,
};

export default FilePanelServiceTab;
