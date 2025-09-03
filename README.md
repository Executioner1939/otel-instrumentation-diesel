# otel-instrumentation-diesel

[![Crates.io](https://img.shields.io/crates/v/otel-instrumentation-diesel.svg)](https://crates.io/crates/otel-instrumentation-diesel)
[![Documentation](https://docs.rs/otel-instrumentation-diesel/badge.svg)](https://docs.rs/otel-instrumentation-diesel)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Maintenance](https://img.shields.io/badge/maintenance-experimental-blue.svg)]()
[![Diesel Version](https://img.shields.io/badge/diesel-2.2.12-green.svg)]()
[![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-Instrumented-blueviolet.svg)]()

OpenTelemetry instrumentation for Diesel ORM, providing automatic tracing and observability for database operations.

> **Note**: This is a fork of the original [`diesel-tracing`](https://github.com/CQCL/diesel-tracing) crate, enhanced with modern Diesel support and improved OpenTelemetry integration.

## Features

- 🚀 **Drop-in Replacement** - Seamlessly replace Diesel connections with instrumented versions
- 📊 **OpenTelemetry Tracing** - Automatic spans for all database operations following [OpenTelemetry semantic conventions](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/database.md)
- 🔍 **Query Visibility** - Optional SQL statement recording for debugging (opt-in via feature flag)
- 🏊 **Connection Pooling** - Full support for r2d2 connection pools
- 🛡️ **Type Safety** - Maintains Diesel's strong type guarantees
- 📈 **Performance** - Minimal overhead with efficient instrumentation
- 🔮 **Future Ready** - Metrics support coming soon

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
  - [PostgreSQL](#postgresql)
  - [MySQL](#mysql)
  - [SQLite](#sqlite)
  - [Connection Pooling with r2d2](#connection-pooling-with-r2d2)
- [Configuration](#configuration)
- [Migration Guide](#migration-guide)
- [Performance Considerations](#performance-considerations)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

```rust
use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
use diesel::prelude::*;

// Replace your regular connection with an instrumented one
let conn = InstrumentedPgConnection::establish("postgresql://localhost/mydb")
    .expect("Error connecting to database");

// Use it exactly like a regular Diesel connection - tracing happens automatically!
let results = users::table
    .filter(users::active.eq(true))
    .load::<User>(&mut conn)
    .expect("Error loading users");
```

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
# Basic setup with your preferred database
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres"] }

# With connection pooling
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres", "r2d2"] }

# With SQL statement recording (use with caution in production)
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres", "statement-fields"] }

# For PostgreSQL with network types
diesel = { version = "2.2.12", features = ["postgres", "network-address"] }
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres"] }
```

### Available Features

| Feature | Description |
|---------|-------------|
| `postgres` | PostgreSQL support (includes network-address types) |
| `mysql` | MySQL/MariaDB support |
| `sqlite` | SQLite support |
| `r2d2` | Connection pooling via r2d2 |
| `statement-fields` | Record SQL statements in spans (⚠️ may expose sensitive data) |

## Usage Examples

### PostgreSQL

```rust
use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
use diesel::prelude::*;
use tracing::{info, instrument};

#[derive(Queryable, Debug)]
struct User {
    id: i32,
    name: String,
    email: String,
}

#[instrument]
fn fetch_active_users(conn: &mut InstrumentedPgConnection) -> QueryResult<Vec<User>> {
    info!("Fetching active users");
    
    users::table
        .filter(users::active.eq(true))
        .order(users::created_at.desc())
        .limit(100)
        .load::<User>(conn)
}

fn main() {
    // Initialize tracing (example with tracing_subscriber)
    tracing_subscriber::fmt::init();
    
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    
    let mut conn = InstrumentedPgConnection::establish(&database_url)
        .expect("Error connecting to PostgreSQL");
    
    // All queries will be automatically traced
    let users = fetch_active_users(&mut conn)
        .expect("Error loading users");
    
    info!("Found {} active users", users.len());
}
```

### MySQL

```rust
use otel_instrumentation_diesel::mysql::InstrumentedMysqlConnection;
use diesel::prelude::*;

fn main() {
    let database_url = "mysql://user:password@localhost/mydb";
    
    let mut conn = InstrumentedMysqlConnection::establish(database_url)
        .expect("Error connecting to MySQL");
    
    // Use connection as normal - all operations are traced
    diesel::sql_query("SELECT VERSION()")
        .execute(&mut conn)
        .expect("Error executing query");
}
```

### SQLite

```rust
use otel_instrumentation_diesel::sqlite::InstrumentedSqliteConnection;
use diesel::prelude::*;

fn main() {
    // In-memory database for testing
    let mut conn = InstrumentedSqliteConnection::establish(":memory:")
        .expect("Error creating SQLite connection");
    
    // File-based database
    let mut conn = InstrumentedSqliteConnection::establish("app.db")
        .expect("Error connecting to SQLite");
    
    // All operations are automatically traced
    diesel::sql_query("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY)")
        .execute(&mut conn)
        .expect("Error creating table");
}

```

### Connection Pooling with r2d2

```rust
use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
use diesel::r2d2::{self, ConnectionManager, Pool};
use diesel::prelude::*;

type DbPool = Pool<ConnectionManager<InstrumentedPgConnection>>;

fn create_pool(database_url: &str) -> DbPool {
    let manager = ConnectionManager::<InstrumentedPgConnection>::new(database_url);
    
    r2d2::Pool::builder()
        .max_size(10)
        .min_idle(Some(5))
        .test_on_check_out(true)
        .build(manager)
        .expect("Failed to create connection pool")
}

fn main() {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    
    let pool = create_pool(&database_url);
    
    // Get a connection from the pool - it's automatically instrumented
    let mut conn = pool.get().expect("Failed to get connection from pool");
    
    // Use the connection as normal
    let user_count: i64 = users::table
        .count()
        .get_result(&mut conn)
        .expect("Error counting users");
    
    println!("Total users: {}", user_count);
}
```

### Generic Connection Handling

Write code that works with both instrumented and regular connections:

```rust
use diesel::prelude::*;
use diesel::pg::Pg;

// Generic function that accepts any PostgreSQL connection
fn count_active_users<C>(conn: &mut C) -> QueryResult<i64>
where
    C: Connection<Backend = Pg>,
{
    users::table
        .filter(users::active.eq(true))
        .count()
        .get_result(conn)
}

// Works with both types
fn main() {
    // Regular connection
    let mut regular_conn = PgConnection::establish("postgresql://localhost/mydb")?;
    let count1 = count_active_users(&mut regular_conn)?;
    
    // Instrumented connection
    let mut instrumented_conn = InstrumentedPgConnection::establish("postgresql://localhost/mydb")?;
    let count2 = count_active_users(&mut instrumented_conn)?;
    
    assert_eq!(count1, count2);
}
```

## Configuration

### OpenTelemetry Setup

```rust
use opentelemetry::trace::TracerProvider;
use opentelemetry::sdk::trace as sdktrace;
use opentelemetry_otlp::WithExportConfig;
use tracing_subscriber::prelude::*;

fn init_telemetry() {
    // Configure OTLP exporter
    let exporter = opentelemetry_otlp::new_exporter()
        .tonic()
        .with_endpoint("http://localhost:4317");
    
    // Build tracer provider
    let provider = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(exporter)
        .with_trace_config(
            sdktrace::config()
                .with_resource(opentelemetry::sdk::Resource::new(vec![
                    opentelemetry::KeyValue::new("service.name", "my-diesel-app"),
                ]))
        )
        .install_batch(opentelemetry::runtime::Tokio)
        .expect("Failed to install OpenTelemetry tracer");
    
    // Set up tracing subscriber with OpenTelemetry layer
    let telemetry_layer = tracing_opentelemetry::layer()
        .with_tracer(provider.tracer("otel-instrumentation-diesel"));
    
    tracing_subscriber::registry()
        .with(telemetry_layer)
        .with(tracing_subscriber::fmt::layer())
        .init();
}
```

### Span Attributes

The instrumentation automatically adds these OpenTelemetry semantic convention attributes to spans:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `db.system` | Database system | `postgresql`, `mysql`, `sqlite` |
| `db.operation` | Operation type | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |
| `db.statement` | SQL statement (if `statement-fields` enabled) | `SELECT * FROM users WHERE id = $1` |
| `otel.status_code` | Operation status | `OK`, `ERROR` |
| `otel.status_message` | Error message (if failed) | Connection error details |

### Security Considerations

#### Statement Recording

SQL statements may contain sensitive information (passwords, personal data, etc.). The `statement-fields` feature is disabled by default. Only enable it in development or with proper data sanitization:

```toml
# Development only
[dependencies.otel-instrumentation-diesel]
version = "0.5.0"
features = ["postgres", "statement-fields"]

# Production - statements not recorded
[dependencies.otel-instrumentation-diesel]
version = "0.5.0"
features = ["postgres"]
```

#### Connection String Security

Connection strings are never recorded in spans as they may contain passwords. Store database credentials securely using environment variables or secret management systems.

## Migration Guide

### From diesel-tracing or diesel-tracing-otel

#### Step 1: Update Dependencies

```toml
# Before (Cargo.toml)
[dependencies]
diesel-tracing = { version = "0.3.1", features = ["postgres", "r2d2"] }
# or
diesel-tracing-otel = { version = "0.2.0", features = ["postgres"] }

# After
[dependencies]
diesel = { version = "2.2.12", features = ["postgres"] }
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres", "r2d2"] }
```

#### Step 2: Update Imports

```rust
// Before
use diesel_tracing::pg::InstrumentedPgConnection;
use diesel_tracing_otel::pg::InstrumentedPgConnection;

// After
use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
```

#### Step 3: Handle Breaking Changes

| Original Feature | Migration Path |
|-----------------|----------------|
| Diesel 2.1.x support | Update to Diesel 2.2.12 or later |
| Network types issues | Fixed - enable `network-address` feature in Diesel |
| Custom span names | Use `#[instrument]` attribute on your functions |
| Trace level configuration | All traces use DEBUG level (configurable via PR welcome) |

### From Regular Diesel Connections

Simply replace your connection types:

```rust
// Before
use diesel::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};

type DbPool = Pool<ConnectionManager<PgConnection>>;

// After
use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
use diesel::r2d2::{ConnectionManager, Pool};

type DbPool = Pool<ConnectionManager<InstrumentedPgConnection>>;
```

## Performance Considerations

### Overhead Analysis

The instrumentation adds minimal overhead to database operations:

- **Span creation**: ~100-200 nanoseconds per query
- **Memory overhead**: One span object per active query
- **Network overhead**: None (tracing is local until exported)

### Best Practices for Production

1. **Disable statement recording in production**
   ```toml
   # Production configuration
   [dependencies.otel-instrumentation-diesel]
   version = "0.5.0"
   features = ["postgres"]  # No "statement-fields"
   ```

2. **Use sampling to reduce trace volume**
   ```rust
   use opentelemetry::sdk::trace::{Sampler, Config};
   
   let trace_config = Config::default()
       .with_sampler(Sampler::TraceIdRatioBased(0.1)); // Sample 10% of traces
   ```

3. **Batch span exports**
   ```rust
   use opentelemetry::sdk::trace::BatchSpanProcessor;
   use std::time::Duration;
   
   let batch_processor = BatchSpanProcessor::builder(exporter)
       .with_max_export_batch_size(512)
       .with_scheduled_delay(Duration::from_secs(5))
       .build();
   ```

4. **Monitor connection pool metrics**
   ```rust
   // Connection pool metrics are automatically traced
   let pool_state = pool.state();
   info!("Connections: {} active, {} idle", 
        pool_state.connections - pool_state.idle_connections,
        pool_state.idle_connections);
   ```

## Troubleshooting

### Common Issues

#### No Traces Appearing

**Problem**: Instrumented connections are being used but no traces appear in your observability platform.

**Solution**: Ensure tracing is properly initialized:
```rust
// Check that a subscriber is installed
if tracing::dispatcher::has_been_set() {
    info!("Tracing is active");
} else {
    eprintln!("WARNING: No tracing subscriber installed!");
}
```

#### Compilation Errors with Network Types

**Problem**: `IpNetwork` type errors when using PostgreSQL.

**Solution**: Enable the `network-address` feature in Diesel:
```toml
[dependencies]
diesel = { version = "2.2.12", features = ["postgres", "network-address"] }
```

#### Performance Degradation

**Problem**: Noticeable slowdown after adding instrumentation.

**Solutions**:
1. Disable `statement-fields` feature
2. Implement sampling (see Performance section)
3. Use batch processing for span exports
4. Check that you're not accidentally creating nested spans in loops

#### Connection Pool Exhaustion

**Problem**: "Cannot get connection from pool" errors.

**Solution**: Instrumented connections work identically to regular connections. Check:
- Pool size configuration
- Long-running transactions
- Proper connection cleanup in error paths

### Debug Logging

Enable debug logging to troubleshoot issues:

```rust
use tracing_subscriber::EnvFilter;

tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::from_default_env()
        .add_directive("otel_instrumentation_diesel=debug".parse()?))
    .init();
```

Then run with:
```bash
RUST_LOG=otel_instrumentation_diesel=debug cargo run
```

## Roadmap

### Current Status

- ✅ Full Diesel 2.2.12 compatibility
- ✅ PostgreSQL, MySQL, SQLite support
- ✅ r2d2 connection pooling
- ✅ OpenTelemetry semantic conventions
- ✅ Optional statement recording

### Coming Soon

- 📊 **Metrics Support** (v0.6.0)
  - Query execution time histograms
  - Connection pool metrics
  - Error rate tracking
  - Query count by operation type

- 🔐 **Enhanced Security** (v0.7.0)
  - Statement sanitization options
  - PII detection and masking
  - Configurable sensitive field filtering

- 🚀 **Performance Optimizations** (v0.8.0)
  - Zero-allocation span creation
  - Compile-time feature detection
  - Async connection support

- 🔧 **Developer Experience** (Future)
  - Migration CLI tool
  - Configuration validation
  - Integration test helpers

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/hermes-capital-io/hermes-platform
cd otel-instrumentation-diesel

# Run tests
cargo test --all-features

# Run benchmarks
cargo bench

# Check formatting and lints
cargo fmt -- --check
cargo clippy --all-features
```

### Testing with Different Backends

```bash
# PostgreSQL
docker run -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:latest
DATABASE_URL="postgresql://postgres:postgres@localhost/test" cargo test --features postgres

# MySQL
docker run -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:latest
DATABASE_URL="mysql://root:root@localhost/test" cargo test --features mysql

# SQLite (no setup needed)
cargo test --features sqlite
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original [`diesel-tracing`](https://github.com/CQCL/diesel-tracing) crate by CQCL
- [Diesel](https://diesel.rs/) ORM team
- [OpenTelemetry](https://opentelemetry.io/) community
- All contributors to this fork

## Support

- 📖 [Documentation](https://docs.rs/otel-instrumentation-diesel)
- 🐛 [Issue Tracker](https://github.com/hermes-capital-io/hermes-platform/issues)
- 💬 [Discussions](https://github.com/hermes-capital-io/hermes-platform/discussions)
- 📧 Email: [shadowrhyder@gmail.com](mailto:shadowrhyder@gmail.com)
