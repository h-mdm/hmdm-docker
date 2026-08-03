# CHANGELOG

All notable changes to the Headwind MDM Docker build will be documented in this file.

## [Fork Published] - 2025-10-02

**Objective:** Make the official container easier to operate behind a reverse proxy with minimal changes while preserving backward compatibility.

### Added
- `rproxy_server.xml` template in `templates/conf/` directory
  - Modified version of `server.xml` that allows Tomcat to respect proxy headers
- `REVERSE_PROXY` environment variable support (defaults to `false`)
- `EFFECTIVE_PROTOCOL` internal variable to preserve original `PROTOCOL` variable

### Changed
- Modified `docker-entrypoint.sh`:
  - Added reverse proxy detection logic
  - Updated server configuration selection based on `REVERSE_PROXY` setting
  - Modified protocol handling in ROOT.xml creation and SQL replacement routines
  - Bypass certbot initialization when operating behind reverse proxy

### Technical Details
- **Backward Compatibility:** Existing deployments continue to work without changes
- **Default Behavior:** All changes are opt-in via the `REVERSE_PROXY=true` environment variable
- **Configuration:** When enabled, replaces default `server.xml` with reverse proxy-aware version