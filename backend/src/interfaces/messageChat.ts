export interface messageChat {
    content: string;
    createdAt: Date;
    username: string;
    id: string;
    audioUrl?: string;
    duration?: number;
}
