from .base import *
from .logging import *

DEBUG = True
for host in ("10.0.2.2", "0.0.0.0", "*"):
    if host not in ALLOWED_HOSTS:
        ALLOWED_HOSTS = list(ALLOWED_HOSTS) + [host]
