import hashlib
import hmac
import ipaddress
import logging
from django.conf import settings

logger = logging.getLogger('users.ip_cooldown')


def normalize_ip(raw_ip: str) -> str:
    """
    Validate and normalize an IPv4 or IPv6 address string.
    Returns normalized compressed IP string, or '127.0.0.1' if invalid.
    """
    if not raw_ip or not isinstance(raw_ip, str):
        return '127.0.0.1'

    ip_str = raw_ip.strip()

    # Strip port if present (e.g. 192.168.1.1:8000 or [2001:db8::1]:8000)
    if ip_str.startswith('[') and ']' in ip_str:
        ip_str = ip_str.split(']')[0].lstrip('[')
    elif ':' in ip_str and '.' in ip_str:
        # IPv4 with port like 1.2.3.4:5678
        ip_str = ip_str.split(':')[0]

    try:
        parsed = ipaddress.ip_address(ip_str)
        return parsed.compressed
    except ValueError:
        logger.warning('[SECURITY] Invalid IP address encountered: %s', raw_ip[:50])
        return '127.0.0.1'


def get_client_ip(request) -> str:
    """
    Extract the real client IP address from request.META.

    Behind trusted reverse proxies (e.g. Render, Cloudflare):
    - True-Client-IP or CF-Connecting-IP take precedence if set by trusted edge.
    - X-Forwarded-For: In a standard single reverse proxy setup (Render),
      the client's actual IP is the rightmost untrusted entry, or the leftmost
      if strictly set by a trusted gateway.
      If X-Forwarded-For contains multiple IPs (e.g. 'client, proxy1, proxy2'),
      we safely extract the validated originating IP.
    - Fallback: REMOTE_ADDR.
    """
    if not request or not hasattr(request, 'META'):
        return '127.0.0.1'

    meta = request.META

    # 1. Direct trusted headers from edge providers
    for header in ('HTTP_TRUE_CLIENT_IP', 'HTTP_CF_CONNECTING_IP', 'HTTP_RENDER_CLIENT_IP'):
        val = meta.get(header)
        if val:
            candidate = val.strip().split(',')[0].strip()
            if candidate:
                return normalize_ip(candidate)

    # 2. X-Forwarded-For
    xff = meta.get('HTTP_X_FORWARDED_FOR')
    if xff:
        # X-Forwarded-For format: client, proxy1, proxy2
        # On Render / AWS ALB, the infrastructure appends client IP
        ips = [ip.strip() for ip in xff.split(',') if ip.strip()]
        if ips:
            # Check configured proxy depth or take the originating client (first or last trusted)
            # Default to first non-private IP or first entry
            candidate = ips[0]
            # If multiple IPs and first is private/loopback, check subsequent
            for ip in ips:
                try:
                    parsed = ipaddress.ip_address(ip)
                    if not parsed.is_private and not parsed.is_loopback:
                        candidate = ip
                        break
                except ValueError:
                    continue
            return normalize_ip(candidate)

    # 3. Direct REMOTE_ADDR
    remote_addr = meta.get('REMOTE_ADDR')
    if remote_addr:
        return normalize_ip(remote_addr)

    return '127.0.0.1'


def hash_ip(ip_address: str) -> str:
    """
    Generate an HMAC-SHA256 digest of the normalized client IP address.
    Does not log or store raw IP addresses.
    Uses SECRET_KEY as the HMAC key.
    """
    normalized = normalize_ip(ip_address)
    key = getattr(settings, 'SECRET_KEY', 'default-ip-cooldown-secret').encode('utf-8')
    return hmac.new(key, normalized.encode('utf-8'), hashlib.sha256).hexdigest()

