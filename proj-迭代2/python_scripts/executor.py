import typing
import os
import math
from multiprocessing import Value, Lock
from concurrent.futures import ProcessPoolExecutor, Future, wait as wait_futures
from functools import partial
from sqlalchemy.exc import DBAPIError, OperationalError


class ProcessAtomicCounter:
    _value: Value
    _lock: Lock
    _total: int
    _initial: int

    def __init__(self, total: int, lock: Lock, initial: int = 0):
        self._total = total
        self._value = Value('i', initial)
        self._lock = lock
        self._initial = initial

    @property
    def value(self) -> int:
        return self._value.value

    @property
    def percentile(self) -> int:
        return int(self._value.value / self._total * 100)

    def increment(self):
        with self._lock:
            self._value.value += 1

    def clear(self):
        with self._lock:
            self._value.value = self._initial
            self.total = 0

    @property
    def total(self):
        return self._total

    @total.setter
    def total(self, _total):
        self._total = _total


GLOBAL_COUNTER = ProcessAtomicCounter(0, Lock())


class RangePKExecuteProcess:
    pk_min: int
    pk_max: int
    model: typing.Any
    func: typing.Callable
    _block_size: typing.ClassVar[int] = 100
    _session_factory: callable
    _retry: int

    def __init__(self, pk_min: int, pk_max: int, model, func: callable, session_factory: callable, retry=3):
        self.pk_min = pk_min
        self.pk_max = pk_max
        self.model = model
        self.func = func
        self._session_factory = session_factory
        self._retry = retry

    def run(self):
        pk_min = self.pk_min
        pk_max = self.pk_max
        _block_size = self._block_size
        _counter = GLOBAL_COUNTER
        _session = self._session_factory()
        func = partial(self.func, _session)
        if (pk_max - pk_min <= _block_size):
            func(_session.query(self.model).filter(self.model.id.between(pk_min, pk_max - 1)))
        pk_range = range(pk_min + _block_size, pk_max, _block_size)
        pk_left = pk_min
        pk_right = 0

        def block_complete():
            try:
                _session.commit()
            except OperationalError:
                _session.rollback()
                return False
            except DBAPIError:
                _session.rollback()
                return False
            except:
                _session.rollback()
                raise
            _counter.increment()
            print(f"\r Process: {_counter.percentile}%", end='')
            return True

        def execute_with_retry(block_left, block_right, retry=3):
            tried = 0
            while True:
                tried += 1
                func(_session.query(self.model).filter(self.model.id.between(block_left, block_right - 1)))
                if (completed := block_complete()):
                    return True
                elif not completed and tried == retry + 1:
                    return False

        for pk_right in pk_range:
            execute_with_retry(pk_left, pk_right, 10)
            pk_left = pk_right

        if pk_right != pk_max:
            execute_with_retry(pk_left, pk_max, 10)

        _session.close()
        return True


class MultiProcessExecutor:
    _pk_list: typing.List[int]
    _futures: typing.List[Future]
    _session_factory: callable
    model: typing.Any

    def __init__(self, pk_list: typing.List[int], model, session_factory: callable):
        self._pk_list = pk_list
        self._pk_list.sort()
        self.model = model
        self._futures = []
        self._session_factory = session_factory

    def run(self, func):
        executor = ProcessPoolExecutor()
        blocks = math.ceil(len(self._pk_list) / RangePKExecuteProcess._block_size)
        GLOBAL_COUNTER.total = blocks
        cpu_count = os.cpu_count()
        if cpu_count is None:
            cpu_count = 1
        cut_points = self._pk_list[::int(len(self._pk_list) / cpu_count)]
        if cut_points[-1] != (pk_max := self._pk_list[-1]):
            cut_points.append(pk_max + 1)
        else:
            cut_points[-1] += 1
        cut_left = cut_points[0]
        for cut_right in cut_points[1:]:
            process = RangePKExecuteProcess(cut_left, cut_right, self.model, func, self._session_factory)
            cut_left = cut_right
            self._futures.append(executor.submit(process.run))

    def wait(self):
        if len(self._futures) == 0:
            return []
        else:
            res = wait_futures(self._futures)
            GLOBAL_COUNTER.clear()
            return res
