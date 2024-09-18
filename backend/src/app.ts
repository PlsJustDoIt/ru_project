import express from 'express';
import mongoose from 'mongoose';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import ruRoutes from './routes/ru.js';
import cors from 'cors';
import fs from 'fs';
import https from 'https';

import dotenv from 'dotenv';
if (process.env.NODE_ENV !== 'production') {
  dotenv.config();
}
import { exit } from 'process';

const app = express();
console.log(process.env.MONGO_URI);

mongoose.set("strictQuery", false);

const isProduction = process.env.NODE_ENV === 'production';

if (process.env.MONGO_URI == null) {
  console.error('MONGO_URI is not defined');
  exit(1);
}


mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('MongoDB Connected'))
  .catch(err => console.error('MongoDB connection error:', err));


app.use(express.json());
app.use(cors());
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/ru', ruRoutes);

const PORT = process.env.PORT || 5000;

if (!isProduction) {
  app.listen(PORT, () => console.log(`Server http running on port ${PORT}`));
} else {
  let options = {
    cert: fs.readFileSync('/etc/ssl/private/server.key'),
    key: fs.readFileSync('/etc/ssl/private/server.crt')
  };
let server = https.createServer(options,app);
server.listen(PORT, () => console.log(`Server https running on port ${PORT}`));

}
