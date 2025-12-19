const mongoose = require('mongoose');

const waterIntakeSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    amount: {
        type: Number,
        required: true,
    },
    type: {
        type: String, // e.g. 'Glass', 'Bottle'
        default: 'Glass',
    },
    date: {
        type: Date,
        default: Date.now,
    },
});

const WaterIntake = mongoose.model('WaterIntake', waterIntakeSchema);

module.exports = WaterIntake;
