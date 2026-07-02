# IBM DB2 Rust Driver API Reference

This document provides a quick reference for the `ibm_db` crate API based on the official examples from https://github.com/ibmdb/rust-ibm_db

## Table of Contents
- [Environment Setup](#environment-setup)
- [Connection](#connection)
- [Statement Execution](#statement-execution)
- [Parameter Binding](#parameter-binding)
- [Result Set Handling](#result-set-handling)
- [Transaction Control](#transaction-control)
- [Connection Pooling](#connection-pooling)

## Environment Setup

```rust
use ibm_db::create_environment_v3;

// Create ODBC environment (version 3)
let env = create_environment_v3().map_err(|e| e.unwrap())?;
```

**Key Points:**
- Always use `create_environment_v3()` for DB2 connections
- Returns `Result<Environment<Version3>, ...>`
- Environment must be kept alive for the duration of connections

## Connection

### Direct Connection String

```rust
use ibm_db::create_environment_v3;

let env = create_environment_v3().map_err(|e| e.unwrap())?;

let connection_string = "DRIVER={IBM DB2 ODBC DRIVER};DATABASE=SAMPLE;HOSTNAME=localhost;PORT=50000;UID=db2admin;PWD=password";

let conn = env.connect_with_connection_string(connection_string)?;
```

**Connection String Format:**
```
DRIVER={IBM DB2 ODBC DRIVER};DATABASE=dbname;HOSTNAME=host;PORT=port;UID=user;PWD=password
```

### Connection Pooling with r2d2

```rust
use ibm_db::ODBCConnectionManager;

let manager = ODBCConnectionManager::new("DRIVER={IBM DB2 ODBC DRIVER};...");
let pool = r2d2::Pool::new(manager).unwrap();

// Get connection from pool
let pool_conn = pool.get().unwrap();
let conn = pool_conn.raw();  // Get raw Connection reference
```

## Statement Execution

### Basic Query Execution

```rust
use ibm_db::{Statement, ResultSetState::{Data, NoData}};

let stmt = Statement::with_parent(&conn)?;

match stmt.exec_direct("SELECT * FROM users")? {
    Data(mut stmt) => {
        // Query returned data - process result set
        let cols = stmt.num_result_cols()?;
        while let Some(mut cursor) = stmt.fetch()? {
            for i in 1..(cols + 1) {
                match cursor.get_data::<&str>(i as u16)? {
                    Some(val) => print!(" {}", val),
                    None => print!(" NULL"),
                }
            }
            println!();
        }
    }
    NoData(_) => {
        // Query executed but returned no data (INSERT, UPDATE, DELETE)
        println!("Query executed, no data returned");
    }
}
```

**Key Points:**
- Use `Statement::with_parent(&conn)` to create a statement
- `exec_direct()` returns `ResultSetState` enum with two variants:
  - `Data(stmt)` - Query returned rows
  - `NoData(stmt)` - Query executed but no rows (DML operations)
- Column indices are 1-based, not 0-based

## Parameter Binding

### Prepared Statements with Parameters

```rust
use ibm_db::{Statement, ResultSetState::Data};

// Prepare statement
let stmt = Statement::with_parent(&conn)?.prepare(
    "SELECT * FROM users WHERE username = ?"
)?;

// Bind parameters (1-based indexing)
let username = "john_doe";
let stmt = stmt.bind_parameter(1, &username)?;

// Execute
match stmt.execute()? {
    Data(mut stmt) => {
        while let Some(mut cursor) = stmt.fetch()? {
            let id: i32 = cursor.get_data(1)?.unwrap();
            let name: String = cursor.get_data(2)?.unwrap();
            println!("ID: {}, Name: {}", id, name);
        }
        stmt.close_cursor()?
    }
    NoData(_) => println!("No results"),
}
```

**Key Points:**
- Use `.prepare()` for parameterized queries
- Use `.bind_parameter(index, &value)` for each parameter
- Parameter indices are 1-based
- Call `.execute()` after binding all parameters
- Use `.reset_parameters()` to reuse the statement with different values

### Multiple Parameters

```rust
let stmt = Statement::with_parent(&conn)?.prepare(
    "INSERT INTO users (username, email, age) VALUES (?, ?, ?)"
)?;

let username = "alice";
let email = "alice@example.com";
let age = 30i32;

let stmt = stmt
    .bind_parameter(1, &username)?
    .bind_parameter(2, &email)?
    .bind_parameter(3, &age)?;

stmt.execute()?;
```

## Result Set Handling

### Fetching Data

```rust
use ibm_db::ResultSetState::Data;

match stmt.exec_direct("SELECT id, name, email FROM users")? {
    Data(mut stmt) => {
        // Fetch rows one at a time
        while let Some(mut cursor) = stmt.fetch()? {
            // Get data by column index (1-based)
            let id: i32 = cursor.get_data(1)?.unwrap_or(0);
            let name: String = cursor.get_data(2)?.unwrap_or_default();
            let email: Option<String> = cursor.get_data(3)?;
            
            println!("ID: {}, Name: {}, Email: {:?}", id, name, email);
        }
    }
    NoData(_) => {}
}
```

**Type Conversions:**
- `cursor.get_data::<i32>(col)` - Integer
- `cursor.get_data::<String>(col)` - String
- `cursor.get_data::<&str>(col)` - String slice
- `cursor.get_data::<f64>(col)` - Float
- Returns `Option<T>` - None for NULL values

### Getting Column Count

```rust
let cols = stmt.num_result_cols()?;
println!("Result set has {} columns", cols);
```

## Transaction Control

### Disabling Autocommit

```rust
use ibm_db::create_environment_v3;

let env = create_environment_v3().map_err(|e| e.unwrap())?;
let mut conn = env.connect_with_connection_string(connection_string)?;

// Disable autocommit to start transaction mode
let mut conn = conn.disable_autocommit()?;
```

### Commit and Rollback

```rust
// Execute operations
let stmt = Statement::with_parent(&conn)?;
stmt.exec_direct("INSERT INTO users (name) VALUES ('Alice')")?;

// Commit the transaction
match conn.commit() {
    Ok(()) => println!("Transaction committed"),
    Err(e) => {
        println!("Commit failed: {}", e);
        conn.rollback()?;  // Rollback on error
    }
}

// Or explicitly rollback
conn.rollback()?;
```

### Re-enabling Autocommit

```rust
// Re-enable autocommit mode
let conn = conn.enable_autocommit()?;
```

**Transaction Pattern:**
```rust
let mut conn = conn.disable_autocommit()?;

match (|| -> Result<(), Box<dyn Error>> {
    // Your database operations here
    let stmt = Statement::with_parent(&conn)?;
    stmt.exec_direct("UPDATE accounts SET balance = balance - 100 WHERE id = 1")?;
    stmt.exec_direct("UPDATE accounts SET balance = balance + 100 WHERE id = 2")?;
    Ok(())
})() {
    Ok(_) => conn.commit()?,
    Err(e) => {
        conn.rollback()?;
        return Err(e);
    }
}
```

## Connection Pooling

### Using r2d2 for Connection Pooling

```rust
use ibm_db::ODBCConnectionManager;
use r2d2::Pool;

// Create connection manager
let manager = ODBCConnectionManager::new(
    "DRIVER={IBM DB2 ODBC DRIVER};DATABASE=SAMPLE;HOSTNAME=localhost;PORT=50000;UID=user;PWD=pass"
);

// Create pool
let pool = Pool::new(manager)?;

// Use connection from pool
let pool_conn = pool.get()?;
let conn = pool_conn.raw();

// Execute queries
let stmt = Statement::with_parent(conn)?;
// ... use statement
```

**Pool Configuration:**
```rust
use r2d2::Pool;

let pool = Pool::builder()
    .max_size(15)  // Maximum connections
    .min_idle(Some(5))  // Minimum idle connections
    .build(manager)?;
```

## Common Patterns

### INSERT and Get Generated ID

```rust
// Insert row
let stmt = Statement::with_parent(&conn)?;
stmt.exec_direct("INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com')")?;

// Get generated ID
let stmt = Statement::with_parent(&conn)?;
match stmt.exec_direct("SELECT IDENTITY_VAL_LOCAL() FROM SYSIBM.SYSDUMMY1")? {
    Data(mut stmt) => {
        if let Some(mut cursor) = stmt.fetch()? {
            let id: i32 = cursor.get_data(1)?.unwrap();
            println!("Generated ID: {}", id);
        }
    }
    NoData(_) => {}
}
```

### Batch Operations

```rust
let stmt = Statement::with_parent(&conn)?.prepare(
    "INSERT INTO users (name, email) VALUES (?, ?)"
)?;

for user in users {
    let stmt = stmt
        .bind_parameter(1, &user.name)?
        .bind_parameter(2, &user.email)?;
    stmt.execute()?;
    let stmt = stmt.reset_parameters()?;
}
```

### Error Handling

```rust
use std::error::Error;

fn query_users() -> Result<Vec<User>, Box<dyn Error>> {
    let env = create_environment_v3().map_err(|e| e.unwrap())?;
    let conn = env.connect_with_connection_string(connection_string)?;
    let stmt = Statement::with_parent(&conn)?;
    
    match stmt.exec_direct("SELECT * FROM users")? {
        Data(mut stmt) => {
            let mut users = Vec::new();
            while let Some(mut cursor) = stmt.fetch()? {
                users.push(User {
                    id: cursor.get_data(1)?.unwrap(),
                    name: cursor.get_data(2)?.unwrap(),
                });
            }
            Ok(users)
        }
        NoData(_) => Ok(Vec::new()),
    }
}
```

## Important Notes

1. **Column Indexing**: All column indices are 1-based, not 0-based
2. **ResultSetState**: Always match on `Data` and `NoData` variants
3. **Cursor Lifetime**: Cursor is only valid during `fetch()` iteration
4. **NULL Handling**: Use `Option<T>` and handle None cases
5. **Environment Lifetime**: Keep environment alive for all connections
6. **Connection String**: Always use `DRIVER={IBM DB2 ODBC DRIVER}` exactly as shown

## See Also

- Official examples in `references/` directory
- GitHub repository: https://github.com/ibmdb/rust-ibm_db
- API documentation: https://docs.rs/ibm_db/