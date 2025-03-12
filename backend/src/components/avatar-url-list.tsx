import React from 'react';
import { BasePropertyProps } from 'adminjs';

const AvatarUrlList: React.FC<BasePropertyProps> = ({ record }) => {
    return (
        <img
            src={record?.params.avatarUrl}
            alt="Avatar"
            style={{ maxWidth: '100px' }}
        />
    );
};

export default AvatarUrlList;
