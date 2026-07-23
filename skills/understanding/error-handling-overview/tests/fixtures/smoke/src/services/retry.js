const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function fetchWithRetry(url, maxRetries = 3) {
    let lastError;
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            const resp = await fetch(url);
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            return resp.json();
        } catch (err) {
            lastError = err;
            if (attempt < maxRetries) {
                const backoff = Math.pow(2, attempt) * 100;
                console.error(`Retry ${attempt}/${maxRetries} for ${url}, waiting ${backoff}ms`);
                await sleep(backoff);
            }
        }
    }
    throw lastError;
}

module.exports = { fetchWithRetry };
