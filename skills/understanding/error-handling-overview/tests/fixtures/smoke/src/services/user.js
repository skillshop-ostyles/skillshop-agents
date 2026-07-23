async function getProfile(userId) {
    try {
        const raw = await db.query('SELECT * FROM profiles WHERE user_id = ?', [userId]);
        return raw;
    } catch (e) {
        // Silently ignore DB errors for profile — not essential
    }
}

module.exports = { getProfile };
