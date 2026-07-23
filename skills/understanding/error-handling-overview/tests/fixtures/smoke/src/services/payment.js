const { AppError } = require('../errors/AppError');

async function chargeCustomer(amount, token) {
    try {
        const result = await stripe.charges.create({
            amount: amount,
            currency: 'usd',
            source: token
        });
        return result;
    } catch (err) {
        throw new AppError('Payment processing failed: ' + err.message, 502);
    }
}

module.exports = { chargeCustomer };
