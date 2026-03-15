# Reverse Proxy Configuration for Headwind MDM

This document provides configuration examples for running Headwind MDM behind a reverse proxy. The reverse proxy functionality allows you to terminate SSL at the proxy level and simplifies deployment in modern containerized environments.

## Overview

When `REVERSE_PROXY=true` is set, Headwind MDM:
- Uses a modified Tomcat configuration that respects proxy headers
- Skips certbot initialization (SSL handled by proxy)
- Properly handles protocol detection from proxy headers
- Maintains full backward compatibility when disabled

## Environment Variables

| Variable | Proxy Setting | Description |
|----------|---------|-------------|
| `REVERSE_PROXY` | `true` | Enable reverse proxy mode |
| `PROTOCOL` | `http` | Use http for MDM. TLS terminates at proxy |
| `BASE_DOMAIN` | Required | Domain name for the service |

***NOTE***
All examples below are generic in nature and not intended to be used as is. 

## Docker Compose Examples

### Traefik Configuration

#### Basic Traefik Setup

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - hmdm-network

  hmdm:
    image: headwindmdm/hmdm:0.1.5
    environment:
      - REVERSE_PROXY=true
      - PROTOCOL=http
      - BASE_DOMAIN=mdm.yourdomain.com
      - SQL_HOST=postgres
      - SQL_BASE=hmdm
      - SQL_USER=hmdm
      - SQL_PASS=topsecret
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.hmdm.rule=Host(`mdm.yourdomain.com`)"
      - "traefik.http.routers.hmdm.entrypoints=websecure"
      - "traefik.http.routers.hmdm.tls=true"
      - "traefik.http.routers.hmdm.tls.certresolver=letsencrypt"
      - "traefik.http.services.hmdm.loadbalancer.server.port=8080"
      # Device communication port
      - "traefik.tcp.routers.hmdm-device.rule=HostSNI(`mdm.yourdomain.com`)"
      - "traefik.tcp.routers.hmdm-device.entrypoints=device-port"
      - "traefik.tcp.routers.hmdm-device.tls=true"
      - "traefik.tcp.services.hmdm-device.loadbalancer.server.port=31000"
    networks:
      - hmdm-network
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=hmdm
      - POSTGRES_USER=hmdm
      - POSTGRES_PASSWORD=topsecret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - hmdm-network

networks:
  hmdm-network:
    driver: bridge

volumes:
  postgres_data:
```

#### Traefik Configuration File (traefik.yml)

```yaml
api:
  dashboard: true
  debug: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true

  websecure:
    address: ":443"

  device-port:
    address: ":31000"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      tlsChallenge: {}
      email: your-email@domain.com
      storage: /acme.json
      keyType: EC256
```

### Nginx Configuration

#### Docker Compose with Nginx

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
      - "31000:31000"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl/certs:ro
    depends_on:
      - hmdm
    networks:
      - hmdm-network

  hmdm:
    image: headwindmdm/hmdm:0.1.5
    environment:
      - REVERSE_PROXY=true
      - PROTOCOL=http
      - BASE_DOMAIN=mdm.yourdomain.com
      - SQL_HOST=postgres
      - SQL_BASE=hmdm
      - SQL_USER=hmdm
      - SQL_PASS=topsecret
    expose:
      - "8080"
      - "31000"
    networks:
      - hmdm-network
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=hmdm
      - POSTGRES_USER=hmdm
      - POSTGRES_PASSWORD=topsecret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - hmdm-network

networks:
  hmdm-network:
    driver: bridge

volumes:
  postgres_data:
```

#### Nginx Configuration File (nginx.conf)

```nginx
events {
    worker_connections 1024;
}

http {
    upstream hmdm_backend {
        server hmdm:8080;
    }

    server {
        listen 80;
        server_name mdm.yourdomain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name mdm.yourdomain.com;

        ssl_certificate /etc/ssl/certs/cert.pem;
        ssl_certificate_key /etc/ssl/certs/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;

        client_max_body_size 100M;

        location / {
            proxy_pass http://hmdm_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }
}

# TCP stream for device communication port
stream {
    upstream hmdm_devices {
        server hmdm:31000;
    }

    server {
        listen 31000;
        proxy_pass hmdm_devices;
        proxy_timeout 1s;
        proxy_responses 1;
    }
}
```

## Kubernetes Examples

### Traefik on Kubernetes

#### Deployment and Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hmdm
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hmdm
  template:
    metadata:
      labels:
        app: hmdm
    spec:
      containers:
      - name: hmdm
        image: headwindmdm/hmdm:0.1.5
        env:
        - name: REVERSE_PROXY
          value: "true"
        - name: PROTOCOL
          value: "http"
        - name: BASE_DOMAIN
          value: "mdm.yourdomain.com"
        - name: SQL_HOST
          value: "postgres-service"
        - name: SQL_BASE
          value: "hmdm"
        - name: SQL_USER
          value: "hmdm"
        - name: SQL_PASS
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 31000
          name: device-port
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: hmdm-service
spec:
  selector:
    app: hmdm
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: device-port
    port: 31000
    targetPort: 31000
  type: ClusterIP
```

#### Traefik IngressRoute

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: hmdm-web
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`mdm.yourdomain.com`)
    kind: Rule
    services:
    - name: hmdm-service
      port: 8080
  tls:
    certResolver: letsencrypt

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteTCP
metadata:
  name: hmdm-device
  namespace: default
spec:
  entryPoints:
    - device-port
  routes:
  - match: HostSNI(`mdm.yourdomain.com`)
    services:
    - name: hmdm-service
      port: 31000
  tls:
    passthrough: false
    secretName: mdm-tls-cert
```

### Nginx Ingress on Kubernetes

#### Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hmdm-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - mdm.yourdomain.com
    secretName: hmdm-tls
  rules:
  - host: mdm.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hmdm-service
            port:
              number: 8080

---
# For device communication port, use a separate service
apiVersion: v1
kind: Service
metadata:
  name: hmdm-device-service
  annotations:
    metallb.universe.tf/allow-shared-ip: "hmdm-shared"
spec:
  selector:
    app: hmdm
  ports:
  - name: device-port
    port: 31000
    targetPort: 31000
    protocol: TCP
  type: LoadBalancer
  loadBalancerIP: your-external-ip  # Optional: specify IP
```

## Troubleshooting

### Common Issues

1. **502 Bad Gateway**
   - Check if HMDM container is running: `docker ps`
   - Verify network connectivity between proxy and HMDM
   - Check HMDM logs: `docker logs <container-name>`

2. **Redirect Loops**
   - Ensure `REVERSE_PROXY=true` is set
   - Verify proxy headers are being sent correctly
   - Check that `PROTOCOL` matches your proxy configuration

3. **Device Connection Issues**
   - Ensure port 31000 is properly proxied
   - For TCP proxying, verify stream configuration in nginx
   - Check firewall rules for port 31000

### Verification Steps

1. **Check container status:**
   ```bash
   docker logs hmdm | grep "REVERSE_PROXY"
   ```

2. **Verify proxy headers:**
   ```bash
   curl -H "Host: mdm.yourdomain.com" \
        -H "X-Forwarded-Proto: https" \
        -H "X-Forwarded-For: 192.168.1.1" \
        http://localhost:8080/
   ```

3. **Test device port:**
   ```bash
   telnet mdm.yourdomain.com 31000
   ```

## Security Considerations

1. **Always use HTTPS** in production environments
2. **Restrict access** to the Traefik/nginx admin interfaces
3. **Keep certificates updated** using automated renewal
4. **Monitor proxy logs** for suspicious activity
5. **Use strong SSL/TLS configurations**

## Performance Tuning

### For High Load Environments

1. **Increase worker connections** in nginx
2. **Enable connection pooling** in reverse proxy
3. **Configure appropriate timeouts** for long-running requests
4. **Use HTTP/2** where supported
5. **Consider load balancing** multiple HMDM instances

### Resource Allocation

```yaml
# Kubernetes resource recommendations
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Migration from Direct Deployment

To migrate from a direct deployment to reverse proxy:

1. **Update environment variables:**
   ```bash
   REVERSE_PROXY=true
   # Keep existing PROTOCOL, BASE_DOMAIN, etc.
   ```

2. **Configure your reverse proxy** using the examples above

3. **Update DNS** to point to your reverse proxy

4. **Test thoroughly** before switching production traffic

5. **Remove certbot** from the HMDM container (handled by proxy)

The reverse proxy mode maintains full compatibility with existing configurations while providing the flexibility needed for modern deployment patterns.