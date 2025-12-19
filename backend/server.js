const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Database Connection
const connectWithRetry = () => {
    console.log('Attempting to connect to MongoDB...');
    mongoose.connect(process.env.MONGO_URI, {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
    })
        .then(() => console.log('MongoDB Connected Successfully'))
        .catch(err => {
            console.error('MongoDB Connection Error:', err.message);
            console.log('Retrying in 5 seconds...');
            setTimeout(connectWithRetry, 5000);
        });
};

connectWithRetry();

// Routes
const authRoutes = require('./routes/authRoutes');
const waterRoutes = require('./routes/waterRoutes');
const userRoutes = require('./routes/userRoutes');

app.use('/api/auth', authRoutes);
app.use('/api/water', waterRoutes);
app.use('/api/users', userRoutes);

app.get('/', (req, res) => {
    res.send('Water Tracker API is running');
});

// Conditionally start server (only if not on Vercel)
if (process.env.NODE_ENV !== 'production') {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Server running on port ${PORT}`);
    });
}

module.exports = app;
