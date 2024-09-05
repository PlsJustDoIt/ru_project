const express = require('express');
const mongoose = require('mongoose');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const ruRoutes = require('./routes/ru');
const cors = require('cors');

require('dotenv').config();

const app = express();
console.log(process.env.MONGO_URI);

mongoose.set("strictQuery", false);


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
