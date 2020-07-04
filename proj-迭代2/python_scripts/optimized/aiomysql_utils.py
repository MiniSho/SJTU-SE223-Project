from aiomysql import Cursor
from typing import Iterable


class AsyncMySqlSession:
    _cursor: Cursor

    def __init__(self, cursor: Cursor):
        self._cursor = cursor

    def __getattr__(self, item):
        return getattr(self._cursor, item)

    def execute(self, query: str, bind: Iterable = None):
        if not bind:
            return self._cursor.execute(query)
        else:
            return self._cursor.execute(query % tuple(bind))

    async def __aenter__(self):
        await self._cursor.execute('START TRANSACTION;')
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            await self._cursor.execute('ROLLBACK;')
            await self._cursor.execute('START TRANSACTION;')
            return False
        else:
            await self._cursor.execute('COMMIT;')
            await self._cursor.execute('START TRANSACTION;')
            return True
