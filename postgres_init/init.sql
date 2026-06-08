CREATE TABLE crm_users (
    user_id INT PRIMARY KEY,
    email VARCHAR(255),
    phone VARCHAR(50),
    loyalty_tier VARCHAR(50),
    signup_date DATE
);

INSERT INTO crm_users (user_id, email, phone, loyalty_tier, signup_date)
SELECT 
    i,
    'user' || i || '@example.com',
    '555-' || lpad((random() * 9999)::int::text, 4, '0'),
    CASE 
        WHEN random() < 0.15 THEN 'Gold' 
        WHEN random() < 0.45 THEN 'Silver' 
        ELSE 'Bronze' 
    END,
    current_date - (random() * 365 * 3)::int
FROM generate_series(1, 206209) AS i;
