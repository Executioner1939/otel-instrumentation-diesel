![Maintenance](https://img.shields.io/badge/maintenance-experimental-blue.svg)

# otel-instrumentation-diesel

> **Note**: This is a fork of the original [`diesel-tracing`](https://github.com/CQCL/diesel-tracing) crate, renamed to `otel-instrumentation-diesel` to provide compatibility with modern Diesel versions and improved OpenTelemetry support.

`otel-instrumentation-diesel` provides connection structures that can be used as drop in
replacements for diesel connections with extra tracing and logging.

## Changes from Original

This fork includes the following improvements:
- ✅ **Updated to Diesel 2.2.12** - Full compatibility with the latest Diesel version
- ✅ **Fixed PostgreSQL network types** - Proper support for `ipnetwork::IpNetwork` with Diesel's `network-address` feature
- ✅ **Enhanced OpenTelemetry integration** - Better tracing and observability support
- ✅ **Maintained API compatibility** - Drop-in replacement for the original crate

## Usage

### Feature flags

Just like diesel this crate relies on some feature flags to specify which
database driver to support. Just as in diesel configure this in your
`Cargo.toml`

```toml
[dependencies]
otel-instrumentation-diesel = { version = "0.5.0", features = ["<postgres|mysql|sqlite>"] }
```

For PostgreSQL with network address support:
```toml
[dependencies]
diesel = { version = "2.2.12", features = ["postgres", "network-address"] }
otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres", "r2d2"] }
```

## Establishing a connection

`otel-instrumentation-diesel` has several instrumented connection structs that wrap the underlying
`diesel` implementations of the connection. As these structs also implement the
`diesel::Connection` trait, establishing a connection is done in the same way as
the `diesel` crate. For example, with the `postgres` feature flag:

```rust
#[cfg(feature = "postgres")]
{
    use otel_instrumentation_diesel::pg::InstrumentedPgConnection;

    let conn = InstrumentedPgConnection::establish("postgresql://example");
}
```

This connection can then be used with diesel dsl methods such as
`diesel::prelude::RunQueryDsl::execute` or `diesel::prelude::RunQueryDsl::get_results`.

## Code reuse

In some applications it may be desirable to be able to use both instrumented and
uninstrumented connections. For example, in the tests for a library. To achieve this
you can use the `diesel::Connection` trait.

```rust
fn use_connection(
    conn: &impl diesel::Connection<Backend = diesel::pg::Pg>,
) -> () {}
```

Will accept both `diesel::PgConnection` and the `InstrumentedPgConnection`
provided by this crate and this works similarly for other implementations
of `Connection` if you change the parametized Backend marker in the
function signature.

Unfortunately there are some methods specific to backends which are not
encapsulated by the `diesel::Connection` trait, so in those places it is
likely that you will just need to replace your connection type with the
Instrumented version.

### Connection Pooling

`otel-instrumentation-diesel` supports the `r2d2` connection pool, through the `r2d2`
feature flag. See `diesel::r2d2` for details of usage.

## Migration from Original

To migrate from the original `diesel-tracing` crate or `diesel-tracing-otel`:

1. **Update your `Cargo.toml`**:
   ```toml
   # Before
   diesel-tracing = { version = "0.3.1", features = ["postgres", "r2d2"] }
   
   # After
   otel-instrumentation-diesel = { version = "0.5.0", features = ["postgres", "r2d2"] }
   ```

2. **Update your imports**:
   ```rust
   // Before
   use diesel_tracing::pg::InstrumentedPgConnection;
   
   // After
   use otel_instrumentation_diesel::pg::InstrumentedPgConnection;
   ```

3. **Ensure Diesel compatibility**:
   - Update to Diesel 2.2.12 or later
   - Enable the `network-address` feature if using PostgreSQL network types

## Notes

### Fields

Currently the few fields that are recorded are a subset of the `OpenTelemetry`
semantic conventions for [databases](https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/database.md).
This was chosen for compatibility with the `tracing-opentelemetry` crate, but
if it makes sense for other standards to be available this could be set by
feature flag later.

Database statements may optionally be recorded by enabling the
`statement-fields` feature. This uses [`diesel::debug_query`](https://docs.rs/diesel/latest/diesel/fn.debug_query.html)
to convert the query into a string. As this may expose sensitive information,
the feature is not enabled by default.

It would be quite useful to be able to parse connection strings to be able
to provide more information, but this may be difficult if it requires use of
diesel feature flags by default to access the underlying C bindings.

### Levels

All logged traces are currently set to DEBUG level, potentially this could be
changed to a different default or set to be configured by feature flags. At
them moment this crate is quite new and it's unclear what a sensible default
would be.

### Errors

Errors in Result objects returned by methods on the connection should be
automatically logged through the `err` directive in the `instrument` macro.

### Sensitive Information

As statements may contain sensitive information they are currently not recorded
explicitly, unless you opt in by enabling the `statement-fields` feature.
Finding a way to filter statements intelligently to solve this problem is a
TODO.

Similarly connection strings are not recorded in spans as they may contain
passwords

### TODO

- [ ] Record and log connection information (filtering out sensitive fields)
- [ ] Provide a way of filtering statements, maybe based on regex?


License: MIT
