CREATE TABLE customers (
    id INT PRIMARY KEY,
    customer_id VARCHAR(50),       -- ambiguous: could be public ID or PII key
    email VARCHAR(255),            -- HIGH PII
    phone VARCHAR(20),             -- MEDIUM PII
    ip_address VARCHAR(45),        -- MEDIUM PII
    notes TEXT,                    -- ambiguous: free text may contain PII
    status_code VARCHAR(20)        -- NONE: non-PII control
);
