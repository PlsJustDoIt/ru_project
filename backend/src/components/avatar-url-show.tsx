import React from 'react';
import { BasePropertyProps } from 'adminjs';

const AvatarUrlShow: React.FC<BasePropertyProps> = ({ record }) => {
    return (
        <img
            src={record?.params.avatarUrl}
            alt="Avatar"
            style={{ maxWidth: '100%' }}
        />
    );
};

export default AvatarUrlShow;
