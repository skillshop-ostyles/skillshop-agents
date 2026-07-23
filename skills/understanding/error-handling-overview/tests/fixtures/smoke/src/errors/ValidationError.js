const { AppError } = require('./AppError');

class ValidationError extends AppError {
    constructor(message, field) {
        super(message, 400);
        this.name = 'ValidationError';
        this.field = field;
    }
}

module.exports = { ValidationError };
