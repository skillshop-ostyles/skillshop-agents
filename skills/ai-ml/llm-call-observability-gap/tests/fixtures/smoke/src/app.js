const OpenAI = require('openai');
const openai = new OpenAI();

// GOOD: observed — error handling + logging + timeout
async function summarize(text) {
    try {
        const response = await openai.chat.completions.create({
            model: 'gpt-4o',
            messages: [{ role: 'user', content: text }],
            max_tokens: 100,
            timeout: 30000
        });
        logger.info('Summary generated', { tokens: response.usage });
        return response.choices[0].message.content;
    } catch (err) {
        logger.error('Summary failed', { error: err.message });
        throw err;
    }
}

// BAD: blind — no error handling, no logging, no timeout
async function classify(text) {
    const response = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: text }]
    });
    return response.choices[0].message.content;
}

// BAD: partially observed — has try/catch but no logging
async function extract(text) {
    try {
        const response = await openai.chat.completions.create({
            model: 'gpt-4o',
            messages: [{ role: 'user', content: text }]
        });
        return response.choices[0].message.content;
    } catch (err) {
        console.error(err);
    }
}
