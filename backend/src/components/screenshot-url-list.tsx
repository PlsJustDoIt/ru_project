import React from 'react';
import { BasePropertyProps } from 'adminjs';

const ScreenshotUrlList: React.FC<BasePropertyProps> = (props) => {
    const { record } = props;
    return (
        <img src={record?.params.screenshot_url} alt="Screenshot" style={{ maxWidth: '100px' }} />
    );
};

export default ScreenshotUrlList;
