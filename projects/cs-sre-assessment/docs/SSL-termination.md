# SSL Termination at the Global Load Balancer

## Overview

Customer HTTPS traffic enters the platform through a Google Global Load Balancer.

The load balancer performs **SSL/TLS termination at the Google edge**, allowing certificates, cryptographic processing, routing logic, and security inspection to be centralized rather than distributed across Kubernetes workloads.

```text
Customer Browser
       |
       | HTTPS
       |
       v
Google Global Load Balancer
       |
       | SSL Terminated
       |
       v
Ingress
       |
       v
Kubernetes Service
       |
       v
Pods
```

## Request Flow

### Step 1: DNS Resolution

The customer accesses:

```text
https://www.yourapp.com
```

Cloud DNS resolves the hostname to the Global Load Balancer IP.

```text
www.yourapp.com
        |
        v
Global Load Balancer IP
```

### Step 2: TLS Handshake

The browser establishes a TLS session with the Google Global Load Balancer.

The load balancer presents:

- TLS certificate
- Public key
- Certificate chain

The browser validates:

- Issuer trust
- Certificate expiration
- Hostname correctness
- Certificate chain integrity

### Step 3: Encrypted Traffic Reaches Google Edge

Traffic arrives at the nearest Google edge location.

```text
Customer
    |
    | HTTPS
    |
    v
Google Edge POP
    |
    v
Global Load Balancer
```

### Step 4: SSL Termination

The Global Load Balancer decrypts the HTTPS request.

Before termination:

```text
Encrypted TLS traffic
```

After termination:

```text
HTTP request path visible
Headers visible
Request metadata visible
```

This allows:

- URI routing
- Cloud Armor inspection
- Health-based routing decisions
- Geographic load balancing
- Backend selection

### Step 5: Backend Routing

After decryption, traffic is forwarded toward the Kubernetes environment.

```text
Global Load Balancer
        |
        v
Ingress
        |
        v
Kubernetes Service
        |
        v
Pods
```

### Step 6: Application Processing

The application processes the request:

```text
App A -> nginx
App B -> hello-app
```

### Step 7: Response to Customer

The response path is:

```text
Pod
  |
  v
Service
  |
  v
Ingress
  |
  v
Load Balancer
  |
  v
Customer
```

The existing TLS session is used when traffic is returned to the browser.

---

# Benefits of SSL Termination

## Centralized Certificate Management

Instead of managing certificates on every application container:

```text
Pod A certificate
Pod B certificate
Pod C certificate
```

only the load balancer requires certificate management.

## Better Performance

TLS encryption and decryption are 