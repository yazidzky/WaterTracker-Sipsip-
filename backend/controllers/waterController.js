const WaterIntake = require('../models/WaterIntake');
const User = require('../models/User');

// @desc    Log water intake
// @route   POST /api/water
// @access  Private
const logIntake = async (req, res) => {
    const { amount, date, type } = req.body;

    if (!amount) {
        res.status(400);
        throw new Error('Please add an amount');
    }

    try {
        const intake = await WaterIntake.create({
            user: req.user.id,
            amount,
            type: type || 'Glass', // Default to Glass if not provided
            date: date || Date.now(),
        });

        res.status(200).json(intake);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server Error' });
    }
};

// @desc    Get water intake history for today
// @route   GET /api/water/today
// @access  Private
const getTodayIntake = async (req, res) => {
    try {
        const { startDate, endDate } = req.query;
        let startOfDay, endOfDay;

        if (startDate && endDate) {
            startOfDay = new Date(startDate);
            endOfDay = new Date(endDate);
        } else {
            startOfDay = new Date();
            startOfDay.setHours(0, 0, 0, 0);

            endOfDay = new Date();
            endOfDay.setHours(23, 59, 59, 999);
        }

        const intakes = await WaterIntake.find({
            user: req.user.id,
            date: { $gte: startOfDay, $lte: endOfDay },
        }).sort({ date: -1 }); // Sort newest first

        const totalAmount = intakes.reduce((acc, intake) => acc + intake.amount, 0);

        res.status(200).json({
            totalAmount,
            intakes,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server Error' });
    }
};

// @desc    Get water intake statistics (custom range or last 7 days)
// @route   GET /api/water/stats
// @access  Private
const getStats = async (req, res) => {
    try {
        const { startDate, endDate } = req.query;
        let query = { user: req.user.id };

        if (startDate && endDate) {
            // Custom range (e.g., for specific week)
            // Ensure we cover the full day of endDate
            const start = new Date(startDate);
            // start.setHours(0, 0, 0, 0);

            const end = new Date(endDate);
            // end.setHours(23, 59, 59, 999);

            query.date = { $gte: start, $lte: end };
        } else {
            // Default: Last 7 days
            const sevenDaysAgo = new Date();
            sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
            sevenDaysAgo.setHours(0, 0, 0, 0);
            query.date = { $gte: sevenDaysAgo };
        }

        const intakes = await WaterIntake.find(query).sort({ date: 1 });

        res.status(200).json(intakes);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server Error' });
    }
};

// @desc    Get water intake statistics for specific month
// @route   GET /api/water/monthly-stats
// @access  Private
const getMonthlyStats = async (req, res) => {
    try {
        const { month, year } = req.query;
        const now = new Date();

        // Use provided month/year or default to current
        // Note: query params are strings, so parse them. Month is 1-based in query usually?
        // Let's assume frontend sends 1-12 for month.
        const targetYear = year ? parseInt(year) : now.getFullYear();
        const targetMonth = month ? parseInt(month) - 1 : now.getMonth(); // JS Month is 0-11

        const startOfMonth = new Date(targetYear, targetMonth, 1);
        const endOfMonth = new Date(targetYear, targetMonth + 1, 0, 23, 59, 59, 999);

        const intakes = await WaterIntake.find({
            user: req.user.id,
            date: { $gte: startOfMonth, $lte: endOfMonth },
        }).sort({ date: 1 }); // Sort by date ascending for easier processing

        res.status(200).json(intakes);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server Error' });
    }
};

// @desc    Delete water intake
// @route   DELETE /api/water/:id
// @access  Private
const deleteIntake = async (req, res) => {
    try {
        const intake = await WaterIntake.findById(req.params.id);

        if (!intake) {
            res.status(404);
            throw new Error('Intake not found');
        }

        // Check for user
        if (!req.user) {
            res.status(401);
            throw new Error('User not found');
        }

        // Make sure the logged in user matches the intake user
        if (intake.user.toString() !== req.user.id) {
            res.status(401);
            throw new Error('User not authorized');
        }

        await intake.deleteOne(); // or intake.remove() depending on mongoose version

        res.status(200).json({ id: req.params.id });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: error.message });
    }
};

module.exports = {
    logIntake,
    getTodayIntake,
    getStats,
    getMonthlyStats,
    deleteIntake
};
