import PropTypes from "prop-types";

export const keywordShape = PropTypes.shape({
  label: PropTypes.string.isRequired,
  url: PropTypes.string.isRequired,
});

export const workItemShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  title: PropTypes.string.isRequired,
  url: PropTypes.string.isRequired,
  thumbnailUrl: PropTypes.string,
  depositor: PropTypes.string,
  keywords: PropTypes.arrayOf(keywordShape).isRequired,
});

export const collectionShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  title: PropTypes.string.isRequired,
  url: PropTypes.string.isRequired,
  thumbnailUrl: PropTypes.string,
});
