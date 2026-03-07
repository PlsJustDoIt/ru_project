interface friendsInSector {
    [key: string]: {
        _id: string;
        username: string;
        status: string;
        avatarUrl: string;
        expiresAt: Date;
    }[];
}

export default friendsInSector;
