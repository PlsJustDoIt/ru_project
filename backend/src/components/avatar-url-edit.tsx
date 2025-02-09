import React from 'react';
import { BasePropertyProps } from 'adminjs';

const AvatarUrlEdit: React.FC<BasePropertyProps> = (props) => {
    const { record, onChange, property } = props;
    return (
        <div>
            {record?.params.avatarUrl && (
                <img
                    src={record.params.avatarUrl}
                    alt="Avatar"
                    style={{ maxWidth: '100px', marginBottom: '10px' }}
                />
            )}
            <input
                type="text"
                value={record?.params.avatarUrl || ''}
                onChange={e => onChange?.(property.name, e.target.value)}
                className="input"
            />
        </div>
    );
};

export default AvatarUrlEdit;
