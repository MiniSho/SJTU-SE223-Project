from redis import Redis
from redis.client import Pipeline
from datetime import date


class RedisCounter:
    _key: str
    _value: int
    _redis: Redis
    _pipeline: Pipeline

    def __init__(self, key: str, /, redis: Redis = None, pipeline: Pipeline = None):
        self._key = key
        self._redis = redis
        self._value = redis.get(key)
        self._pipeline = pipeline

    @property
    def value(self) -> int:
        return self._value

    @property
    def key(self) -> str:
        return self._key

    def incr(self) -> int:
        self._value = self._redis.incr(self._key)
        return self._value

    def decr(self) -> int:
        self._value = self._redis.decr(self._key)
        return self._value


class AppointStatCounter(RedisCounter):
    def __init__(self, doctor_plan_id: int, app_date: date, redis: Redis):
        super().__init__(f"app_stat_{doctor_plan_id}_{app_date}", redis)
