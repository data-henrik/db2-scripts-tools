#!/bin/bash

# Script: run_explain.sh
# Purpose: Run SQL script in Db2 explain mode and format the output
# Usage: ./run_explain.sh <database_name> <sql_script> <output_file>

# Check if correct number of arguments provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <database_name> <sql_script> <output_file>"
    echo "Example: $0 MYDB query.sql query.sql.exfmt"
    exit 1
fi

# Assign parameters to variables
DATABASE_NAME="$1"
SQL_SCRIPT="$2"
OUTPUT_FILE="$3"

# Check if SQL script exists
if [ ! -f "$SQL_SCRIPT" ]; then
    echo "Error: SQL script '$SQL_SCRIPT' not found"
    exit 1
fi

echo "================================================"
echo "Db2 Explain Script Runner"
echo "================================================"
echo "Database: $DATABASE_NAME"
echo "SQL Script: $SQL_SCRIPT"
echo "Output File: $OUTPUT_FILE"
echo "================================================"

# Connect to database and run explain
echo "Connecting to database and setting explain mode..."
db2 connect to "$DATABASE_NAME"

if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to database '$DATABASE_NAME'"
    exit 1
fi

echo "Setting explain mode to EXPLAIN..."
db2 "SET CURRENT EXPLAIN MODE EXPLAIN"

if [ $? -ne 0 ]; then
    echo "Error: Failed to set explain mode"
    db2 connect reset
    exit 1
fi

echo "Running SQL script: $SQL_SCRIPT"
db2 -tvf "$SQL_SCRIPT" 2>&1 | tee /tmp/db2_explain_output.log

# Check for actual errors (not SQL0217W which is expected in explain mode)
if grep -q "SQL[0-9]*N" /tmp/db2_explain_output.log; then
    echo "Error: SQL script execution failed with errors"
    db2 "SET CURRENT EXPLAIN MODE NO"
    db2 connect reset
    rm -f /tmp/db2_explain_output.log
    exit 1
fi

# SQL0217W is expected when running in explain mode, so we don't treat it as an error
if grep -q "SQL0217W" /tmp/db2_explain_output.log; then
    echo "Note: SQL0217W received (expected in explain mode - statement explained but not executed)"
fi

rm -f /tmp/db2_explain_output.log

echo "Setting explain mode back to NO..."
db2 "SET CURRENT EXPLAIN MODE NO"

echo "Disconnecting from database..."
db2 connect reset

echo "================================================"
echo "Formatting explain output..."
echo "================================================"

# Format the explain output
db2exfmt -d "$DATABASE_NAME" -1 -o "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "Success! Explain output formatted and saved to: $OUTPUT_FILE"
    echo ""
    echo "================================================"
    echo "To view the formatted explain output, run:"
    echo "================================================"
    echo "cat $OUTPUT_FILE"
    echo ""
    echo "Or to view with pagination:"
    echo "less $OUTPUT_FILE"
    echo "================================================"
else
    echo "Error: Failed to format explain output"
    exit 1
fi

exit 0

