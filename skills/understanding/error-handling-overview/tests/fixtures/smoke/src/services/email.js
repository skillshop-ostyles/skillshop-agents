function sendEmail(recipient, template) {
    return emailProvider.send(recipient, template)
        .catch(err => {
            console.error('Email delivery failed, using fallback provider', err.message);
            return fallbackProvider.send(recipient, template);
        });
}

module.exports = { sendEmail };
