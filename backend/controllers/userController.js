const User = require('../models/User');

// @desc    Update user profile
// @route   PUT /api/users/profile
// @access  Private
const updateProfile = async (req, res) => {
    const user = await User.findById(req.user.id);

    if (user) {
        user.name = req.body.name || user.name;
        user.email = req.body.email || user.email;
        user.gender = req.body.gender || user.gender;
        user.age = req.body.age || user.age;
        user.weight = req.body.weight || user.weight;
        user.activityLevel = req.body.activityLevel || user.activityLevel;
        user.healthConditions = req.body.healthConditions || user.healthConditions;
        user.dailyGoal = req.body.dailyGoal || user.dailyGoal;

        if (req.body.avatar) user.avatar = req.body.avatar;
        if (req.body.isDarkMode !== undefined) user.isDarkMode = req.body.isDarkMode;

        if (req.body.password) {
            user.password = req.body.password;
        }

        const updatedUser = await user.save();

        res.json({
            _id: updatedUser._id,
            name: updatedUser.name,
            email: updatedUser.email,
            gender: updatedUser.gender,
            age: updatedUser.age,
            weight: updatedUser.weight,
            dailyGoal: updatedUser.dailyGoal,
            avatar: updatedUser.avatar,
            sound: updatedUser.sound,
            language: updatedUser.language,
            isDarkMode: updatedUser.isDarkMode,
            token: req.body.token, // Keep the same token
        });
    } else {
        res.status(404);
        throw new Error('User not found');
    }
};

module.exports = {
    updateProfile,
};
