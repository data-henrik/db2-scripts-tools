---
name: rust-db2-dev
description: Use this skill for developing Rust applications that interact with IBM Db2 databases using the official ibm_db Rust driver. Trigger this whenever the user mentions Rust with Db2, database connectivity in Rust, creating Rust database applications, CRUD operations with Db2, or needs help with the ibm_db crate for Db2 connectivity. Also use when they want to build REST APIs, CLI tools, or any Rust application that needs to connect to Db2 LUW databases. This skill covers connection management, query execution, error handling, prepared statements, transaction management, and project structure best practices using the native IBM Db2 driver. Make sure to use this skill whenever Rust and Db2 are mentioned together, even if the user doesn't explicitly ask for the ibm_db crate.
---

# Rust + Db2 Development Skill

This skill helps you build robust Rust applications that interact with IBM Db2 databases (LUW - Linux, Unix, Windows) using the official `ibm_db` Rust driver from IBM.

## Critical: Understanding the ibm_db API

**IMPORTANT**: The `ibm_db` crate has a specific API that differs from generic ODBC libraries. Before writing any code, you MUST consult the `references/API_REFERENCE.md` file in this skill directory for the correct API usage patterns.

**Key API Facts:**
- Use `create_environment_v3()` to create the environment
- Use `env.connect_with_connection_string()` to connect
- Use `Statement::with_parent(&conn)` to create statements
- `exec_direct()` returns `ResultSetState` enum with `Data` or `NoData` variants
- Column indices are 1-based (start at 1, not 0)
- Use `cursor.get_data::<T>(col_index)` to retrieve values
- For connection pooling, use `ODBCConnectionManager` with r2d2

## When to Consult References

**ALWAYS read `references/API_REFERENCE.md` when:**
- Creating database connections
- Executing queries
- Binding parameters
- Handling result sets
- Managing transactions
- Setting up connection pools

The reference file contains working examples from the official repository that show the exact API usage.

## Core Principles

**Why Rust for Db2?**
Rust provides memory safety, excellent performance, and strong type safety - making it ideal for database applications where data integrity and performance matter. The `ibm_db` crate is the official IBM driver providing native Db2 connectivity.

**Why ibm_db over generic ODBC?**
The `ibm_db` crate is IBM's official Rust driver, providing direct access to Db2's native CLI. This offers better performance, more complete feature support, and easier setup compared to generic ODBC drivers.

## Prerequisites

Before starting, ensure you have:
1. **Rust toolchain** (1.45 or later)
2. **IBM Db2 client libraries** installed on your system
3. **Environment variables** set correctly:
   - `IBM_DB_HOME` pointing to clidriver directory
   - Library path (`LD_LIBRARY_PATH` on Linux, `DYLD_LIBRARY_PATH` on macOS, `PATH` on Windows)

### Installing Db2 Client Libraries

The `ibm_db` crate requires IBM DB2 CLI Driver. You can install it using the setup utility from the rust-ibm_db repository:

```bash
git clone https://github.com/ibmdb/rust-ibm_db.git
cd rust-ibm_db
cargo run --bin setup
```

This will download and install the appropriate driver for your platform.

## Project Setup

### Dependencies

Create a `Cargo.toml` with these dependencies:

```toml
[package]
name = "your-project-name"
version = "0.1.0"
edition = "2021"

[dependencies]
ibm_db = "1.0"
anyhow = "1.0"
thiserror = "1.0"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
chrono = { version = "0.4", features = ["serde"] }
dotenv = "0.15"

# For connection pooling
r2d2 = "0.8"

[dev-dependencies]
tokio = { version = "1", features = ["full"] }
```

### Environment Configuration

Create a `.env` file:

```env
DB2_CONNECTION_STRING=DRIVER={IBM DB2 ODBC DRIVER};DATABASE=SAMPLE;HOSTNAME=localhost;PORT=50000;UID=db2admin;PWD=your_password
```

Create a `.env.example` without sensitive data for version control.

## Project Structure

```
project-root/
├── Cargo.toml
├── .env
├── .env.example
├── .gitignore
├── README.md
├── src/
│   ├── main.rs              # Entry point
│   ├── lib.rs               # Library root (if building a library)
│   ├── db/
│   │   ├── mod.rs           # Database module
│   │   ├── connection.rs    # Connection management
│   │   ├── error.rs         # Custom error types
│   │   └── models.rs        # Data models
│   ├── repository/
│   │   ├── mod.rs
│   │   └── user_repo.rs     # Example repository
│   └── config.rs            # Configuration loading
├── tests/
│   └── integration_test.rs
└── examples/
    └── basic_query.rs
```

## Connection Management

### Basic Connection

**CRITICAL**: Always consult `references/API_REFERENCE.md` for the exact connection pattern.

```rust
use ibm_db::create_environment_v3;
use std::error::Error;

fn connect() -> Result<(), Box<dyn Error>> {
    // Create environment
    let env = create_environment_v3().map_err(|e| e.unwrap())?;
    
    // Connection string
    let connection_string = "DRIVER={IBM DB2 ODBC DRIVER};DATABASE=SAMPLE;HOSTNAME=localhost;PORT=50000;UID=db2admin;PWD=password";
    
    // Connect
    let conn = env.connect_with_connection_string(connection_string)?;
    
    println!("Connected successfully!");
    Ok(())
}
```

### Connection Manager Pattern

Create `src/db/connection.rs`:

```rust
use ibm_db::create_environment_v3;
use anyhow::Result;

pub struct ConnectionManager {
    connection_string: String,
}

impl ConnectionManager {
    pub fn new(connection_string: String) -> Self {
        Self { connection_string }
    }

    pub fn get_connection(&self) -> Result<ibm_db::Connection<ibm_db::safe::AutocommitOn>> {
        let env = create_environment_v3().map_err(|e| e.unwrap())?;
        let conn = env.connect_with_connection_string(&self.connection_string)?;
        Ok(conn)
    }
}
```

**Why this pattern?**
The environment is created fresh for each connection. For production applications with high concurrency, use connection pooling (see below).

### Connection Pooling with r2d2

```rust
use ibm_db::ODBCConnectionManager;
use r2d2::Pool;

pub fn create_pool(connection_string: &str) -> Result<Pool<ODBCConnectionManager>> {
    let manager = ODBCConnectionManager::new(connection_string.to_string());
    let pool = Pool::builder()
        .max_size(15)
        .build(manager)?;
    Ok(pool)
}

// Usage
let pool = create_pool(&connection_string)?;
let pool_conn = pool.get()?;
let conn = pool_conn.raw();  // Get raw Connection reference
```

## Error Handling

Define custom errors in `src/db/error.rs`:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DbError {
    #[error("Database connection failed: {0}")]
    ConnectionError(String),
    
    #[error("Query execution failed: {0}")]
    QueryError(String),
    
    #[error("No rows found")]
    NotFound,
    
    #[error("Data conversion error: {0}")]
    ConversionError(String),
    
    #[error("Transaction error: {0}")]
    TransactionError(String),
}

impl From<ibm_db::DiagnosticRecord> for DbError {
    fn from(err: ibm_db::DiagnosticRecord) -> Self {
        DbError::QueryError(err.to_string())
    }
}
```

## CRUD Operations

### Data Models

Define your data structures in `src/db/models.rs`:

```rust
use serde::{Deserialize, Serialize};
use chrono::NaiveDateTime;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: i32,
    pub username: String,
    pub email: String,
    pub created_at: NaiveDateTime,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewUser {
    pub username: String,
    pub email: String,
}
```

### Repository Pattern

**CRITICAL**: Before implementing repositories, read `references/API_REFERENCE.md` for correct query execution patterns.

Implement CRUD operations in `src/repository/user_repo.rs`:

```rust
use crate::db::{connection::ConnectionManager, error::DbError, models::{User, NewUser}};
use ibm_db::{Statement, ResultSetState::{Data, NoData}};
use anyhow::Result;
use chrono::NaiveDateTime;

pub struct UserRepository {
    conn_manager: ConnectionManager,
}

impl UserRepository {
    pub fn new(conn_manager: ConnectionManager) -> Self {
        Self { conn_manager }
    }

    pub fn create(&self, new_user: &NewUser) -> Result<i32> {
        let conn = self.conn_manager.get_connection()?;
        
        // Insert the user
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!(
            "INSERT INTO users (username, email, created_at, is_active) VALUES ('{}', '{}', CURRENT TIMESTAMP, 1)",
            new_user.username, new_user.email
        );
        
        match stmt.exec_direct(&sql)? {
            Data(s) => { let _ = s.close_cursor()?; }
            NoData(_) => {}
        }
        
        // Get the generated ID
        let stmt = Statement::with_parent(&conn)?;
        match stmt.exec_direct("SELECT IDENTITY_VAL_LOCAL() FROM SYSIBM.SYSDUMMY1")? {
            Data(mut stmt) => {
                if let Some(mut cursor) = stmt.fetch()? {
                    let id: i32 = cursor.get_data(1)?.unwrap_or(0);
                    Ok(id)
                } else {
                    Err(DbError::QueryError("Failed to get generated ID".into()).into())
                }
            }
            NoData(_) => Err(DbError::QueryError("No data returned for ID".into()).into()),
        }
    }

    pub fn find_by_id(&self, id: i32) -> Result<Option<User>> {
        let conn = self.conn_manager.get_connection()?;
        
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!(
            "SELECT id, username, email, created_at, is_active FROM users WHERE id = {}",
            id
        );
        
        match stmt.exec_direct(&sql)? {
            Data(mut stmt) => {
                if let Some(mut cursor) = stmt.fetch()? {
                    let user = User {
                        id: cursor.get_data(1)?.unwrap_or(0),
                        username: cursor.get_data(2)?.unwrap_or_default(),
                        email: cursor.get_data(3)?.unwrap_or_default(),
                        created_at: parse_timestamp(&cursor.get_data::<String>(4)?.unwrap_or_default())?,
                        is_active: cursor.get_data::<i16>(5)?.unwrap_or(0) != 0,
                    };
                    Ok(Some(user))
                } else {
                    Ok(None)
                }
            }
            NoData(_) => Ok(None),
        }
    }

    pub fn find_all(&self) -> Result<Vec<User>> {
        let conn = self.conn_manager.get_connection()?;
        
        let stmt = Statement::with_parent(&conn)?;
        let sql = "SELECT id, username, email, created_at, is_active FROM users";
        
        match stmt.exec_direct(sql)? {
            Data(mut stmt) => {
                let mut users = Vec::new();
                
                while let Some(mut cursor) = stmt.fetch()? {
                    let user = User {
                        id: cursor.get_data(1)?.unwrap_or(0),
                        username: cursor.get_data(2)?.unwrap_or_default(),
                        email: cursor.get_data(3)?.unwrap_or_default(),
                        created_at: parse_timestamp(&cursor.get_data::<String>(4)?.unwrap_or_default())?,
                        is_active: cursor.get_data::<i16>(5)?.unwrap_or(0) != 0,
                    };
                    users.push(user);
                }
                
                Ok(users)
            }
            NoData(_) => Ok(Vec::new()),
        }
    }

    pub fn update(&self, user: &User) -> Result<()> {
        let conn = self.conn_manager.get_connection()?;
        
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!(
            "UPDATE users SET username = '{}', email = '{}', is_active = {} WHERE id = {}",
            user.username, user.email, user.is_active as i16, user.id
        );
        
        match stmt.exec_direct(&sql)? {
            Data(s) => { let _ = s.close_cursor()?; }
            NoData(_) => {}
        }
        
        Ok(())
    }

    pub fn delete(&self, id: i32) -> Result<()> {
        let conn = self.conn_manager.get_connection()?;
        
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!("DELETE FROM users WHERE id = {}", id);
        
        match stmt.exec_direct(&sql)? {
            Data(s) => { let _ = s.close_cursor()?; }
            NoData(_) => {}
        }
        
        Ok(())
    }
}

fn parse_timestamp(s: &str) -> Result<NaiveDateTime> {
    NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S%.f")
        .or_else(|_| NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S"))
        .map_err(|e| DbError::ConversionError(e.to_string()).into())
}
```

**IMPORTANT NOTE**: The above example uses string formatting for simplicity. For production code with user input, you MUST use prepared statements with parameter binding to prevent SQL injection. See `references/bind_params.rs` for the correct pattern.

### Using Prepared Statements (Recommended)

For queries with user input, always use prepared statements:

```rust
pub fn find_by_username(&self, username: &str) -> Result<Option<User>> {
    let conn = self.conn_manager.get_connection()?;
    
    // Prepare statement
    let stmt = Statement::with_parent(&conn)?.prepare(
        "SELECT id, username, email, created_at, is_active FROM users WHERE username = ?"
    )?;
    
    // Bind parameter
    let stmt = stmt.bind_parameter(1, username)?;
    
    // Execute
    match stmt.execute()? {
        Data(mut stmt) => {
            if let Some(mut cursor) = stmt.fetch()? {
                let user = User {
                    id: cursor.get_data(1)?.unwrap_or(0),
                    username: cursor.get_data(2)?.unwrap_or_default(),
                    email: cursor.get_data(3)?.unwrap_or_default(),
                    created_at: parse_timestamp(&cursor.get_data::<String>(4)?.unwrap_or_default())?,
                    is_active: cursor.get_data::<i16>(5)?.unwrap_or(0) != 0,
                };
                Ok(Some(user))
            } else {
                Ok(None)
            }
        }
        NoData(_) => Ok(None),
    }
}
```

## Transaction Management

**CRITICAL**: Read `references/transaction_control.rs` for the complete transaction pattern.

```rust
pub fn transfer_funds(&self, from_id: i32, to_id: i32, amount: f64) -> Result<()> {
    let conn = self.conn_manager.get_connection()?;
    
    // Disable autocommit
    let mut conn = conn.disable_autocommit()?;
    
    match (|| -> Result<()> {
        // Deduct from source
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!("UPDATE accounts SET balance = balance - {} WHERE id = {}", amount, from_id);
        match stmt.exec_direct(&sql)? {
            Data(s) => { let _ = s.close_cursor()?; }
            NoData(_) => {}
        }
        
        // Add to destination
        let stmt = Statement::with_parent(&conn)?;
        let sql = format!("UPDATE accounts SET balance = balance + {} WHERE id = {}", amount, to_id);
        match stmt.exec_direct(&sql)? {
            Data(s) => { let _ = s.close_cursor()?; }
            NoData(_) => {}
        }
        
        Ok(())
    })() {
        Ok(_) => {
            conn.commit()?;
            Ok(())
        }
        Err(e) => {
            conn.rollback()?;
            Err(e)
        }
    }
}
```

## Configuration Management

Create `src/config.rs`:

```rust
use anyhow::{Context, Result};
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub connection_string: String,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        dotenv::dotenv().ok();
        
        let connection_string = env::var("DB2_CONNECTION_STRING")
            .context("DB2_CONNECTION_STRING must be set")?;
        
        Ok(Self { connection_string })
    }
}
```

## Testing

### Integration Tests

Create `tests/integration_test.rs`:

```rust
use your_crate::{
    db::connection::ConnectionManager,
    repository::UserRepository,
    config::Config,
};

#[test]
fn test_user_crud() {
    let config = Config::from_env().expect("Failed to load config");
    let conn_manager = ConnectionManager::new(config.connection_string);
    let repo = UserRepository::new(conn_manager);
    
    // Test CRUD operations
    // ... (similar to previous examples)
}
```

## Examples

Create `examples/basic_query.rs`:

```rust
use your_crate::{config::Config, db::connection::ConnectionManager};
use ibm_db::{Statement, ResultSetState::Data};

fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    let conn_manager = ConnectionManager::new(config.connection_string);
    let conn = conn_manager.get_connection()?;
    
    let stmt = Statement::with_parent(&conn)?;
    
    match stmt.exec_direct("SELECT * FROM users")? {
        Data(mut stmt) => {
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
        NoData(_) => println!("No data returned"),
    }
    
    Ok(())
}
```

## Best Practices

### 1. Always Use Prepared Statements for User Input
Never use string formatting with user input. Always use `.prepare()` and `.bind_parameter()`.

### 2. Handle ResultSetState Correctly
Always match on both `Data` and `NoData` variants when calling `exec_direct()` or `execute()`.

### 3. Column Indices are 1-Based
Remember that column indices start at 1, not 0. `cursor.get_data(1)` gets the first column.

### 4. Handle NULL Values
Use `Option<T>` and handle None cases explicitly.

### 5. Keep Environment Alive
The environment must remain alive for the duration of all connections derived from it.

### 6. Use Connection Pooling for Production
For applications with multiple concurrent requests, use `ODBCConnectionManager` with r2d2.

## Common Db2 Data Type Mappings

| Db2 Type | Rust Type | Notes |
|----------|-----------|-------|
| INTEGER | i32 | |
| BIGINT | i64 | |
| SMALLINT | i16 | |
| DECIMAL(p,s) | f64 or String | Use String for exact precision |
| VARCHAR(n) | String | |
| CHAR(n) | String | May be padded with spaces |
| TIMESTAMP | String | Parse with chrono |
| DATE | String | Parse with chrono |
| TIME | String | Parse with chrono |
| BLOB | Vec<u8> | |
| CLOB | String | |
| BOOLEAN/SMALLINT | i16 | 0 = false, 1 = true |

## Troubleshooting

### Connection Issues
- Verify `IBM_DB_HOME` is set correctly
- Check library path environment variable
- Test connection with: `odbcinst -j` and `isql -v DSN username password`

### Compilation Errors
- Ensure IBM DB2 CLI Driver is installed
- Verify environment variables are set before running `cargo build`
- Check that OpenSSL development files are installed

### Runtime Errors
- "Driver not found": Check connection string uses `DRIVER={IBM DB2 ODBC DRIVER}` exactly
- "Symbol not found": Library path not set correctly
- "Connection failed": Verify hostname, port, database name, credentials

## Output Format

When creating a Rust + Db2 project, provide:

1. **Complete project structure** with all necessary files
2. **Cargo.toml** with `ibm_db` and dependencies
3. **Source files** organized by module (db/, repository/, etc.)
4. **Configuration files** (.env.example, .gitignore)
5. **Test files** with integration tests
6. **Example files** demonstrating usage
7. **README.md** with setup instructions and prerequisites
8. **SQL schema** if creating tables

Ensure all code follows the patterns shown in `references/API_REFERENCE.md` and the example files in `references/`.

## Additional Resources

- **API Reference**: See `references/API_REFERENCE.md` in this skill directory
- **Working Examples**: See `references/*.rs` files for complete working examples
- **Official Repository**: https://github.com/ibmdb/rust-ibm_db
- **API Documentation**: https://docs.rs/ibm_db/
- **IBM Db2 Documentation**: https://www.ibm.com/docs/en/db2