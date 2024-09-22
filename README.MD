# CDN Load Balancing and Caching Strategies

## Start

1. Start the CDN setup:
   ```bash
   $ docker-compose up -d
   ```

2. Test Load Balancer 1 (Port 8080):
   ```bash
   $ curl -I http://localhost:8080/image.png
   ```
   - First request: `X-Cache-Status: MISS`
   - Subsequent requests: `X-Cache-Status: HIT`

3. Test Load Balancer 2 (Port 8081):
   ```bash
   $ curl -I http://localhost:8081/image.png
   ```
   - First request: `X-Cache-Status: MISS`
   - Subsequent requests: `X-Cache-Status: HIT`

### Cache Expiration

- Cached successful responses (`200 OK`) are stored for **60 minutes**
- Cached `404 Not Found` responses are stored for **1 minute**
- After these periods, the cache will expire, and the next request will return `MISS` again


## Load Balancing Approaches

### 1. Round Robin Load Balancing
Requests are distributed evenly across all available backend servers in a rotating sequential order.

```nginx
upstream cdn_backend {
    server node1;
    server node2;
    server node3;
    server node4;
}

server {
    listen 80;

    location / {
        proxy_pass http://cdn_backend;
    }
}
```

**Pros**:
- Simple implementation
- Traffic is evenly distributed among all backend nodes
- Effective when all servers have similar capacity

**Cons**:
- Does not account for server load, so a slow or overloaded server will still receive traffic
- Not efficient for systems where backend server performance can vary greatly

### 2. Least Connections Load Balancing
Requests are directed to the backend server with the fewest active connections at the time.
This is already implemented in **Load Balancer 1 (lb1)**.
```nginx
upstream cdn_backend {
    least_conn;
    server node1;
    server node2;
    server node3;
    server node4;
}

server {
    listen 80;

    location / {
        proxy_pass http://cdn_backend;
    }
}
```

**Pros**:
- Efficient when servers have varying capacities
- Helps to avoid overloading servers with more connections
- Dynamic adjustment based on real-time load, which balances the system better during traffic spikes

**Cons**:
- May still suffer from uneven traffic distribution if there are large variations in connection durations across servers

### 3. IP Hashing Load Balancing
Ensures that requests from the same client (based on their IP address) always go to the same backend server.

```nginx
upstream cdn_backend {
    ip_hash;
    server node1;
    server node2;
    server node3;
    server node4;
}

server {
    listen 80;

    location / {
        proxy_pass http://cdn_backend;
    }
}
```

**Pros**:
- Ensures session persistence for clients (sticky sessions), which is useful for stateful applications
- Keeps the load distributed across servers for different clients

**Cons**:
- If one server is down, clients mapped to that server may experience issues
- Can lead to uneven distribution if a large number of clients are behind the same IP (e.g., corporate networks)

## Caching Strategies

### 1. Proxy Caching in NGINX

NGINX can cache responses from the backend servers and serve them directly from the cache for future requests. This greatly reduces the load on backend servers and improves performance.
This is already implemented in **Load Balancer 2 (lb2)**.

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=static_cache:10m max_size=1g inactive=60m use_temp_path=off;

server {
    listen 80;

    location / {
        proxy_pass http://cdn_backend;

        proxy_cache static_cache;
        proxy_cache_valid 200 60m;  # Cache for 60 minutes
        proxy_cache_valid 404 1m;   # Cache 404 responses for 1 minute

        add_header X-Cache-Status $upstream_cache_status;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        proxy_cache_bypass $http_cache_control;
    }
}
```

**Pros**:
- Reduces load on backend servers by serving cached responses for repeated requests
- Improves client response times since cached content is served directly from the load balancer
- Reduces backend server costs by offloading traffic
- NGINX can cache both successful responses (200) and errors (404)

**Cons**:
- Cache invalidation can be complex if content changes frequently
- Disk space can be consumed quickly if cache is not managed properly (e.g., using the `max_size` directive)
- Cache might become stale if not configured with proper expiration rules

### 2. Cache-Control Headers and Cache Invalidation  
The `Cache-Control` header allows you to manage how long the client and the load balancer should cache content. You can also bypass the cache when needed by setting the `Cache-Control: no-cache` header

**Pros**:
- Fine control over cache expiration based on content type or endpoint
- Can prevent clients from receiving outdated content if the cache is not invalidated properly

**Cons**:
- Requires careful management to avoid serving stale content to users
- If misconfigured, it can lead to frequent cache invalidations, reducing the benefits of caching

## Comparison of Load Balancing Strategies

| Strategy        | Pros | Cons |
|-----------------|------|------|
| **Round Robin** | Simple, equal distribution of requests. | Doesn’t account for server load or performance variations. |
| **Least Connections** | Efficient for servers with varying capacities or traffic loads. | Slightly more complex to configure, and connection duration may skew load. |
| **IP Hashing** | Sticky sessions, ensuring the same client is always directed to the same server. | Can lead to uneven distribution, especially with corporate networks behind a single IP. |

## Comparison of Caching Strategies

| Strategy                        | Pros | Cons |
|----------------------------------|------|------|
| **Proxy Caching in NGINX**       | Reduces backend load, improves response times, efficient for repeated content | Cache invalidation can be tricky; stale content may be served |
| **Cache-Control Headers**        | Fine-tuned control over caching behavior and expiration | Misconfigurations can reduce caching efficiency and cause performance degradation |

## Conclusion

- **Round Robin**: Best for scenarios where backend servers have roughly equal capacity
- **Least Connections**: Ideal for dynamic environments where backend server load can vary significantly
- **IP Hashing**: Useful for sticky sessions but may lead to uneven load distribution

On the caching side, **NGINX proxy caching** provides efficient content caching, but **Cache-Control headers** allow fine-tuning of expiration and cache control.
