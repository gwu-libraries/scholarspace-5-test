const FILE_GROUPS = [
  { label: 'hOCR Files',      test: (name) => name.endsWith('.hocr') },
  { label: 'PDF Derivatives', test: (name) => name.endsWith('.pdf') },
  { label: 'Transcripts',     test: (name) => name.endsWith('.vtt') },
  { label: 'Thumbnails',      test: (name) => ['.jpg', '.jpeg', '.png', '.tif', '.tiff', '.gif', '.webp'].includes(name.match(/\.[^.]+$/)?.[0] ?? '') },
  { label: 'Other',           test: () => true },
];

const ORIGINAL_FILE_GROUPS = [
  { label: 'Audio / Video', test: (member) => member.isAv },
  { label: 'PDFs',          test: (member) => member.isPdf },
  { label: 'Images',        test: (member) => isImageMember(member) },
  { label: 'Other',         test: () => true },
];

const IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.tif', '.tiff', '.webp', '.jp2'];

function isImageMember(member) {
  if (member.isImage) return true;
  const label = (member.label || '').toLowerCase();
  return IMAGE_EXTENSIONS.some((ext) => label.endsWith(ext));
}

function groupByRules(members, rules, getValue) {
  const placed = new Set();

  return rules.reduce((groups, rule) => {
    const matched = members.filter((member) => !placed.has(member.id) && rule.test(getValue(member)));
    matched.forEach((member) => placed.add(member.id));
    if (matched.length > 0) groups.push({ label: rule.label, members: matched });
    return groups;
  }, []);
}

function groupServiceMembers(members) {
  return groupByRules(members, FILE_GROUPS, (member) => member.label.toLowerCase());
}

function groupOriginalMembers(members) {
  return groupByRules(members, ORIGINAL_FILE_GROUPS, (member) => member);
}

function isRepresentativeThumbnail(member) {
  return Boolean(member.isRepresentativeThumbnail);
}

export {
  FILE_GROUPS,
  IMAGE_EXTENSIONS,
  ORIGINAL_FILE_GROUPS,
  groupOriginalMembers,
  groupServiceMembers,
  isImageMember,
  isRepresentativeThumbnail,
};
