import React from 'react';
import { BasePropertyProps } from 'adminjs';

const ScreenshotUrlEdit: React.FC<BasePropertyProps> = (props) => {
    const { record, onChange, property } = props;
    return (
        <div>
            {record?.params.screenshot_url && (
                <img src={record.params.screenshot_url} alt="Screenshot" style={{ maxWidth: '100px', marginBottom: '10px' }} />
            )}
            <input
                type="text"
                value={record?.params.screenshot_url || ''}
                onChange={e => onChange?.(property.name, e.target.value)}
                className="input"
            />
        </div>
    );
};

export default ScreenshotUrlEdit;
