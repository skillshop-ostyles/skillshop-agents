CREATE TABLE customers (
    cst_id INT PRIMARY KEY,
    cst_nm VARCHAR(100) NOT NULL,
    cst_email VARCHAR(255),
    cst_phn VARCHAR(20),
    flg_active CHAR(1) DEFAULT 'Y',
    crt_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    ord_id INT PRIMARY KEY,
    cst_id INT NOT NULL,
    ord_dt TIMESTAMP NOT NULL,
    ord_sts VARCHAR(20) DEFAULT 'pending',
    ord_total DECIMAL(10,2),
    FOREIGN KEY (cst_id) REFERENCES customers(cst_id)
);

CREATE TABLE products (
    prd_id INT PRIMARY KEY,
    prd_nm VARCHAR(200) NOT NULL,
    prd_desc TEXT,
    prd_price DECIMAL(10,2) NOT NULL,
    prd_qty INT DEFAULT 0,
    cat_nm VARCHAR(100)
);
