# Part 5 — Written Question

## Q1. Migrating ~40 ingress-nginx Ingress objects to Gateway API with no downtime

I would treat this as a gradual migration rather than replacing all 40 objects at once.

1. **Inventory and baseline:** export the existing Ingress objects, hosts, paths, TLS configuration, annotations, rewrite rules, authentication, rate limits, and backend Services. Capture current traffic/error-rate metrics and certificate behaviour.
2. **Install the Gateway API implementation:** deploy the selected Gateway controller alongside ingress-nginx. Create the required GatewayClass and a shared Gateway with listeners for HTTP/HTTPS. Keep ingress-nginx serving production traffic during this phase.
3. **Migrate a low-risk application first:** create HTTPRoute resources that reproduce one existing Ingress. Validate routing, TLS, redirects, headers, health checks, observability, and application behaviour.
4. **Run both paths:** keep the old Ingress resources active while validating Gateway API routes. Gradually migrate applications in batches and monitor 4xx/5xx rates, latency, TLS errors, and controller events.
5. **Switch traffic safely:** where possible, use controlled DNS/load-balancer changes or another supported traffic-shifting mechanism. Reduce DNS TTL ahead of the migration and keep the old path available for rollback.
6. **Remove ingress-nginx only after validation:** once all applications have migrated and rollback is no longer required, remove the old Ingress resources and then retire ingress-nginx.

The main risks are unsupported ingress-nginx annotations, differences in path matching and rewrites, TLS/certificate handling, authentication or rate-limiting features, controller-specific behaviour, and applications that depend on undocumented defaults. I would test these explicitly before each migration batch.
