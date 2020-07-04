from redis import Redis
from aioredis import create_pool, ConnectionsPool
from typing import Coroutine

REDIS_HOST = "172.17.0.4"
REDIS_PORT = 6379
REDIS_DB = 0


def redis_factory() -> Redis:
    return Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)


async def async_redis_pool() -> Coroutine[None, None, ConnectionsPool]:
    return await create_pool(f"redis://{REDIS_HOST}:{REDIS_PORT}", db=REDIS_DB, maxsize=100)
