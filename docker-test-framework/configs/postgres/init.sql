-- Initialize test database
CREATE DATABASE IF NOT EXISTS test_results;

-- Create test results table
\c test_results;

CREATE TABLE IF NOT EXISTS test_runs (
    id SERIAL PRIMARY KEY,
    test_suite VARCHAR(50) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration INTERVAL,
    success BOOLEAN,
    results JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS test_metrics (
    id SERIAL PRIMARY KEY,
    test_run_id INTEGER REFERENCES test_runs(id),
    metric_name VARCHAR(100) NOT NULL,
    metric_value NUMERIC,
    metric_unit VARCHAR(20),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_test_runs_suite ON test_runs(test_suite);
CREATE INDEX IF NOT EXISTS idx_test_runs_start_time ON test_runs(start_time);
CREATE INDEX IF NOT EXISTS idx_test_metrics_name ON test_metrics(metric_name);
