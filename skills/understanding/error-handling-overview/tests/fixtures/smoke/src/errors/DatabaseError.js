const { AppError } = require('./AppError');

class DatabaseError extends AppError {
    constructor(message, query) {
        super(message, 500);
        this.name = 'DatabaseError';
        this.query = query;
    }
}

module.exports = { DatabaseError };
