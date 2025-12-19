const User = require('../models/User');
const jwt = require('jsonwebtoken');

// Generate JWT
const generateToken = (id) => {
    return jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: '30d',
    });
};

// @desc    Register new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res) => {
    const { name, email, password, avatar } = req.body;

    try {
        if (!name || !email || !password) {
            return res.status(400).json({ message: 'Please add all fields' });
        }

        // Check if user exists
        const userExists = await User.findOne({ email });

        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Create user
        const user = await User.create({
            name,
            email,
            password,
            avatar: avatar || 'avatar1.png', // Use provided avatar or default
            // Default values for other fields can be updated later in profile
        });

        if (user) {
            res.status(201).json({
                _id: user.id,
                name: user.name,
                email: user.email,
                avatar: user.avatar,
                token: generateToken(user._id),
            });
        } else {
            res.status(400).json({ message: 'Invalid user data' });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Authenticate a user
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res) => {
    const { email, password } = req.body;

    try {
        const user = await User.findOne({ email });

        if (user && (await user.matchPassword(password))) {
            res.json({
                _id: user.id,
                name: user.name,
                email: user.email,
                token: generateToken(user._id),
            });
        } else {
            res.status(401).json({ message: 'Invalid credentials' });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Get user data
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password');
        res.status(200).json(user);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server Error' });
    }
}

// @desc    Sync user from Google
// @route   POST /api/auth/google
// @access  Public
const googleAuth = async (req, res) => {
    const { name, email, photoURL, googleId } = req.body;

    try {
        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        // Find user by email
        let user = await User.findOne({ email });

        if (user) {
            // Existing user - log them in
            // Update photo if provided and changed
            if (photoURL && user.avatar !== photoURL) {
                user.avatar = photoURL;
                await user.save();
            }

            res.status(200).json({
                _id: user.id,
                name: user.name,
                email: user.email,
                token: generateToken(user._id),
                avatar: user.avatar,
            });
        } else {
            // New user - needs to register
            // Return 404 with Google data for pre-filling registration form
            res.status(404).json({
                message: 'User not registered',
                needsRegistration: true,
                googleData: {
                    name: name || email.split('@')[0],
                    email: email,
                    googleId: googleId,
                },
            });
        }
    } catch (error) {
        console.error('Google Auth Sync Error:', error);
        res.status(500).json({ message: 'Server error during Google sync' });
    }
};
// @desc    Delete user account
// @route   DELETE /api/auth/delete
// @access  Private
const deleteUser = async (req, res) => {
    try {
        await User.findByIdAndDelete(req.user.id);
        res.status(200).json({ message: 'User deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
    registerUser,
    loginUser,
    getMe,
    deleteUser,
    googleAuth,
};
