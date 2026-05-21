const FILE_GROUPS = [
  { label: 'hOCR Files',      test: (name) => name.endsWith('.hocr') },
  { label: 'PDF Derivatives', test: (name) => name.endsWith('.pdf') },
  { label: 'Transcripts',     test: (name) => name.endsWith('.vtt') },
  { label: 'Thumbnails',      test: (name) => ['.jpg', '.jpeg', '.png', '.tif', '.tiff', '.gif', '.webp'].includes(name.match(/\.[^.]+$/)?.[0] ?? '') },
  { label: 'Other',           test: () => true },
];

const ORIGINAL_FILE_GROUPS = [
  { label: 'Audio / Video', test: (member) => isAvMember(member) },
  { label: 'PDFs',          test: (member) => member.isPdf },
  { label: 'Images',        test: (member) => isImageMember(member) },
  { label: 'Other',         test: () => true },
];

const IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.tif', '.tiff', '.webp', '.jp2'];
const AV_EXTENSIONS = ['.mp3', '.wav', '.m4a', '.aac', '.flac', '.ogg', '.oga', '.mp4', '.m4v', '.mov', '.avi', '.mkv', '.webm', '.mpeg', '.mpg'];

function isAvMember(member) {
  if (member.isAv) return true;
  const label = (member.label || '').toLowerCase();
  return AV_EXTENSIONS.some((ext) => label.endsWith(ext));
}

function isImageMember(member) {
  if (member.isImage) return true;
  const label = (member.label || '').toLowerCase();
  return IMAGE_EXTENSIONS.some((ext) => label.endsWith(ext));
}

function memberViewerType(member) {
  if (isAvMember(member)) return 'ramp';
  if (member.isPdf) return 'pdf';
  if (isImageMember(member)) return 'images';
  return null;
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
  AV_EXTENSIONS,
  IMAGE_EXTENSIONS,
  ORIGINAL_FILE_GROUPS,
  groupOriginalMembers,
  groupServiceMembers,
  isAvMember,
  isImageMember,
  memberViewerType,
  isRepresentativeThumbnail,
};
