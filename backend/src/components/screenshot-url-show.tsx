import React from 'react';
import { BasePropertyProps } from 'adminjs';

const ScreenshotUrlShow: React.FC<BasePropertyProps> = (props) => {
    const { record } = props;
    return (
        <img
            src={record?.params.screenshot_url}
            alt="Screenshot"
            style={{
                width: '100%',
                height: 'auto',
                maxWidth: '400px',
                display: 'block',
            }}
        />
    );
};

export default ScreenshotUrlShow;
