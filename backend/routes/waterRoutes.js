const express = require('express');
const router = express.Router();
const { logIntake, getTodayIntake, getStats, getMonthlyStats, deleteIntake } = require('../controllers/waterController');
const { protect } = require('../middleware/authMiddleware');

router.post('/', protect, logIntake);
router.get('/today', protect, getTodayIntake);
router.get('/stats', protect, getStats);
router.get('/monthly-stats', protect, getMonthlyStats);
router.delete('/:id', protect, deleteIntake);

module.exports = router;
