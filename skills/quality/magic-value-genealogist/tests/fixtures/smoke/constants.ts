// Fixture for magic-value-genealogist.
// Contains 86400 twice (with different meanings!), 0.19 once, a string constant.

const RETRY_BACKOFF_SECONDS = 86400;        // 1 day, but as seconds.
const CACHE_TTL_MS = 86400;                  // Same number, ms.
const VAT_RATE = 0.19;
const MAX_RETRIES = 0.19;                    // Mis-labeled: not 19% - same number!
const DEFAULT_STATUS = "PENDING_APPROVAL";
