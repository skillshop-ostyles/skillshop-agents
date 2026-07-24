-- Schema Health Scanner - Smoke Test Fixture
-- 4 tables: healthy, no-PK, mixed-naming, god-table

CREATE TABLE customers (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(200) NOT NULL,
    billing_address TEXT,
    credit_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customers_email ON customers (email);
CREATE INDEX idx_customers_status ON customers (status);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    total DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    shipping_address TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_status ON orders (status);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id ON order_items (order_id);

-- Table 2: no PK, no timestamps (append-only audit log)
CREATE TABLE audit_log (
    message TEXT NOT NULL,
    severity VARCHAR(10) NOT NULL DEFAULT 'info',
    source VARCHAR(100),
    correlation_id VARCHAR(64)
);

CREATE INDEX idx_audit_log_severity ON audit_log (severity);
CREATE INDEX idx_audit_log_correlation_id ON audit_log (correlation_id);

-- Table 3: mixed naming conventions (camelCase + snake_case)
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    productName VARCHAR(255) NOT NULL,
    product_price DECIMAL(12, 2) NOT NULL,
    product_desc TEXT,
    category_id INTEGER NOT NULL REFERENCES customers(id),
    SKU VARCHAR(50) NOT NULL,
    isActive BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_category_id ON products (category_id);
CREATE INDEX idx_products_sku ON products (SKU);

-- Table 4: god table (22 columns)
CREATE TABLE user_settings (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    theme VARCHAR(20) NOT NULL DEFAULT 'light',
    language VARCHAR(10) NOT NULL DEFAULT 'en',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    push_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    sms_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_emails BOOLEAN NOT NULL DEFAULT FALSE,
    two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    session_timeout_minutes INTEGER NOT NULL DEFAULT 60,
    max_login_attempts INTEGER NOT NULL DEFAULT 5,
    dashboard_layout VARCHAR(50) NOT NULL DEFAULT 'default',
    items_per_page INTEGER NOT NULL DEFAULT 25,
    font_size VARCHAR(10) NOT NULL DEFAULT 'medium',
    color_blind_mode BOOLEAN NOT NULL DEFAULT FALSE,
    auto_save_interval_seconds INTEGER NOT NULL DEFAULT 30,
    default_currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    date_format VARCHAR(20) NOT NULL DEFAULT 'YYYY-MM-DD',
    number_format VARCHAR(10) NOT NULL DEFAULT '1,234.56',
    week_starts_on VARCHAR(10) NOT NULL DEFAULT 'monday',
    working_hours_start TIME NOT NULL DEFAULT '09:00',
    working_hours_end TIME NOT NULL DEFAULT '17:00'
);

CREATE INDEX idx_user_settings_user_id ON user_settings (user_id);
