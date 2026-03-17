import React from "react";
import PropTypes from "prop-types";
import Viewer from "@samvera/clover-iiif/viewer";
import * as styles from "./Clover.module.css";

import "swiper/css";
import "swiper/css/navigation";
import "swiper/css/pagination";

const Clover = ({ manifestUrl }) => {
    return (
        <div className={styles.wrapper}>
            <article className={styles.viewer}>
                <Viewer iiifContent={manifestUrl} />
            </article>
        </div>
    );
};

Clover.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
};

export default Clover;