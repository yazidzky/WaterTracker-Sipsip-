const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    email: {
        type: String,
        required: true,
        unique: true,
    },
    password: {
        type: String,
        required: true,
    },
    gender: {
        type: String,
        enum: ['Laki-laki', 'Perempuan', 'Pria', 'Wanita'], // Relaxed to handle existing localized data
    },
    age: {
        type: Number,
    },
    weight: {
        type: Number,
    },
    activityLevel: {
        type: String, // e.g., 'Sedentary', 'Active'
    },
    healthConditions: [{
        type: String, // e.g., 'Hamil', 'Menyusui'
    }],
    dailyGoal: {
        type: Number,
        default: 2000, // Default 2000ml
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
    sound: {
        type: String,
        default: 'Dering',
    },
    language: {
        type: String,
        default: 'Indonesia',
    },
    isDarkMode: {
        type: Boolean,
        default: false,
    },
    avatar: {
        type: String,
        default: 'avatar1.png',
    },
});

// Password hashing middleware
userSchema.pre('save', async function (next) {
    if (!this.isModified('password')) {
        next();
    }
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
});

// Method to compare passwords
userSchema.methods.matchPassword = async function (enteredPassword) {
    return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model('User', userSchema);

module.exports = User;
