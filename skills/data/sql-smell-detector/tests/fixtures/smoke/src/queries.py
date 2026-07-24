# Missing WHERE
q4 = "SELECT * FROM audit_logs"

# Implicit cast (heuristic) - phone likely varchar, value is numeric
q5 = "SELECT id FROM customers WHERE phone = 1234567890"
