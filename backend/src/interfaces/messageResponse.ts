interface MessageResponse {
    content: string;
    createdAt: Date;
    username: string;
    id: string;
    audioUrl?: string;
    duration?: number;
}

export default MessageResponse;
