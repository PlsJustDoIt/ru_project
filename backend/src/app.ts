import express from 'express';
import mongoose from 'mongoose';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import ruRoutes from './routes/ru';
import cors from 'cors';

import dotenv from 'dotenv';
dotenv.config();
import { exit } from 'process';

const app = express();
console.log(process.env.MONGO_URI);

mongoose.set("strictQuery", false);

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
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
