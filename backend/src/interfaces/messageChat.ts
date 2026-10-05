export interface messageChat {
    content: string;
    createdAt: Date;
    username: string;
    /** Id de l'expéditeur : identifie « mes » messages même après un changement de pseudo. */
    userId?: string;
    avatarUrl?: string;
    id: string;
    audioUrl?: string;
    duration?: number;
}
