# Socket Service Documentation

## Overview
The SocketService manages real-time communication and messaging between clients using Socket.IO, with support for global and private rooms.

## Authentication
The service uses JWT authentication for socket connections:
```typescript
socket.handshake.auth.token || socket.handshake.query.token
```

## Room Types
1. **Global Room**: Public room where all authenticated users can join
2. **Private Rooms**: Created between two friends for private messaging

## Events

### Server -> Client Events
- `room_joined` - Emitted when successfully joined a room
  ```typescript
  socket.emit('room_joined', ({ roomId: string }) => {})
  ```
- `receive_message` - Emitted when a new message is received
  ```typescript
  socket.emit('receive_message', ({ message: MessageResponse }) => {})
  ```
- `userOffline` - Emitted when a user disconnects
  ```typescript
  socket.emit('userOffline', (userId: string) => {})
  ```
- `error` - Emitted when an error occurs
  ```typescript
  socket.emit('error', (message: string) => {})
  ```

### Client -> Server Events
- `join_global_room` - Join the global chat room
  ```typescript
  socket.on('join_global_room')
  ```
- `join_room` - Join a private room with a friend
  ```typescript
  socket.on('join_room', friendId: string)
  ```
- `leave_room` - Leave a specific room
  ```typescript
  socket.on('leave_room', roomId: string)
  ```

## REST API Endpoints

### Messages
- `POST /send` - Send a message to a specific room
  - Required body: `{ roomId: string, content: string }`
  - Authentication required

- `POST /send-chat-room` - Send a message to global chat
  - Required body: `{ content: string }`
  - Authentication required

- `GET /messages` - Get messages for a specific room
  - Query params: `roomName`
  - Authentication required

- `GET /chat-room` - Get messages from global chat
  - Authentication required

- `DELETE /delete-messages` - Delete all messages in a room
  - Query params: `roomId`
  - Authentication required

## Message Response Format
```typescript
interface MessageResponse {
    content: string;
    createdAt: Date;
    username: string;
    id: string;
}
```

## Error Handling
The service includes comprehensive error handling:
- Socket connection errors
- Authentication errors
- Room joining/leaving errors
- Message sending errors
- Invalid room/user IDs

## Utility Methods
- `isUserOnline(userId)` - Check if a user is connected
- `emitToUser(event, userId, data)` - Send event to specific user
- `emitToRoom(event, roomId, data)` - Broadcast to room
- `broadcastToEveryone(event, data)` - Broadcast to all connected users
