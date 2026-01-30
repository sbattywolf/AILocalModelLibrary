"""Role arbitration and simple scheduling helper.

This module provides a minimal `RoleDescriptor` schema and a `RoleArbiter`
that can nominate the best role for a given task context, estimate time,
and signal when internet/permissions block execution.

This is intentionally small and heuristic-based so it can be extended later.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Callable, Awaitable, Union

from services.comm import internet_policy
import threading
import time
import asyncio
import inspect


@dataclass
class RoleDescriptor:
    name: str
    skills: List[str] = field(default_factory=list)
    allowed_network: Optional[bool] = None
    max_parallel_jobs: int = 1
    preferred: bool = False
    weight: int = 1


# Handler type: accepts task_ctx and returns either None, a dict-like status,
# or an awaitable that resolves to the same. Example: Callable[[Dict[str, Any]],
# Union[None, Dict[str, Any], Awaitable[Union[None, Dict[str, Any]]]]]
Handler = Callable[[Dict[str, Any]], Union[None, Dict[str, Any], Awaitable[Union[None, Dict[str, Any]]]]]


class RoleArbiter:
    """Collects role descriptors and nominates a role for a task.

    Public API:
    - `add_role(role: RoleDescriptor)`
    - `collect_roles()` -> List[RoleDescriptor]
    - `evaluate(task_ctx: dict) -> dict` nominate best role and estimate time
    """

    def __init__(self):
        self._roles: List[RoleDescriptor] = []
        # record of activation attempts: list of dicts {role, task_ctx, status}
        self._activations: List[Dict[str, Any]] = []
        # simple job queue (no execution yet)
        self._job_queue: List[Dict[str, Any]] = []
        # executor control
        self._executor_threads: List[threading.Thread] = []
        self._executor_stop = threading.Event()
        self._queue_lock = threading.Lock()
        self._activations_lock = threading.Lock()
        # track running jobs per role
        self._running_counts: Dict[str, int] = {}
        # optional job handlers per role: `Handler` as defined above
        self._job_handlers: Dict[str, Handler] = {}
        # (simple approach) no shared async loop; handlers will use `asyncio.run`

    def add_role(self, role: RoleDescriptor) -> None:
        self._roles.append(role)

    def collect_roles(self) -> List[RoleDescriptor]:
        return list(self._roles)

    def _score_role(self, role: RoleDescriptor, task_ctx: Dict[str, Any]) -> int:
        # score based on skill overlap, preference, and configured weight
        req_skills = set(task_ctx.get("required_skills", []))
        skill_match = len(req_skills.intersection(set(role.skills)))
        score = skill_match * 10
        if role.preferred:
            score += 5
        score += role.weight
        return score

    def _estimate(self, role: RoleDescriptor, task_ctx: Dict[str, Any]) -> int:
        # simple heuristic: base 10s + 5s per matched skill * complexity
        req_skills = set(task_ctx.get("required_skills", []))
        skill_match = len(req_skills.intersection(set(role.skills)))
        complexity = float(task_ctx.get("complexity", 1.0)) or 1.0
        est = int(max(10, 5 * max(1, skill_match) * complexity))
        return est

    def evaluate(self, task_ctx: Dict[str, Any], dialog_manager: Optional[object] = None) -> Dict[str, Any]:
        """Nominate the best role for `task_ctx`.

        Returns a dict with keys:
        - `role`: selected role name or None
        - `score`: numeric score
        - `est_seconds`: estimated seconds to complete
        - `needs_internet`: True if task requires internet but no role is allowed
        - `reason`: human-readable reason
        """
        candidates = []
        requires_internet = bool(task_ctx.get("requires_internet", False))

        for r in self._roles:
            # determine network allowance: explicit allowed_network overrides policy check
            allowed_network = r.allowed_network
            if allowed_network is None:
                # consult global policy for the role
                allowed_network = internet_policy.is_internet_allowed(role=r.name)

            # if task requires internet and this role lacks network permission, mark low-priority
            if requires_internet and not allowed_network:
                # skip for now; keep as candidate with negative flag
                candidates.append((r, -1, False))
                continue

            score = self._score_role(r, task_ctx)
            candidates.append((r, score, True))

        # filter feasible candidates (positive score and allowed)
        feasible = [(r, s) for (r, s, ok) in [(c[0], c[1], c[2]) for c in candidates] if s > 0]

        if not feasible:
            # if none feasible but internet required, indicate needs_internet
            if requires_internet:
                # notify dialog manager about missing internet if provided
                if dialog_manager and hasattr(dialog_manager, "_raise_impediment"):
                    try:
                        dialog_manager._raise_impediment("internet_required", {"task": task_ctx}, weight=5)
                    except Exception:
                        pass
                return {"role": None, "score": 0, "est_seconds": None, "needs_internet": True, "reason": "no role allowed network or matching skills"}
            return {"role": None, "score": 0, "est_seconds": None, "needs_internet": False, "reason": "no matching role"}

        # pick highest score
        feasible.sort(key=lambda x: x[1], reverse=True)
        selected, score = feasible[0]
        est = self._estimate(selected, task_ctx)
        result = {"role": selected.name, "score": int(score), "est_seconds": int(est), "needs_internet": False, "reason": "nomination"}
        # notify dialog manager of nomination if it implements `on_role_nomination`
        if dialog_manager and hasattr(dialog_manager, "on_role_nomination"):
            try:
                dialog_manager.on_role_nomination(selected.name, result)
            except Exception:
                pass
        return result

    def activate_role(self, role_name: str, task_ctx: Dict[str, Any], dialog_manager: Optional[object] = None) -> Dict[str, Any]:
        """Record an activation attempt for the named role.

        This does not execute any work; it records the activation intent and
        returns a status object. Later steps will implement actual execution.
        """
        role = next((r for r in self._roles if r.name == role_name), None)
        if role is None:
            status = {"role": role_name, "status": "unknown_role", "task": task_ctx}
            self._activations.append(status)
            return status

        # check network requirement
        requires_internet = bool(task_ctx.get("requires_internet", False))
        allowed_network = role.allowed_network
        if allowed_network is None:
            allowed_network = internet_policy.is_internet_allowed(role=role.name)

        if requires_internet and not allowed_network:
            status = {"role": role_name, "status": "blocked_internet", "task": task_ctx}
            self._activations.append(status)
            # notify dialog manager if available
            if dialog_manager and hasattr(dialog_manager, "_raise_impediment"):
                try:
                    dialog_manager._raise_impediment("internet_required", {"role": role_name, "task": task_ctx}, weight=5)
                except Exception:
                    pass
            return status

        # record successful activation intent
        status = {"role": role_name, "status": "activated", "task": task_ctx}
        self._activations.append(status)
        # also enqueue a job placeholder
        self._job_queue.append({"role": role_name, "task": task_ctx})
        return status

    def get_activations(self) -> List[Dict[str, Any]]:
        return list(self._activations)

    def schedule_job(self, role_name: str, task_ctx: Dict[str, Any]) -> None:
        """Enqueue a job for later execution (non-blocking, no worker yet)."""
        with self._queue_lock:
            self._job_queue.append({"role": role_name, "task": task_ctx})

    def register_handler(self, role_name: str, handler: Handler) -> None:
        """Register a handler for a role.

        Handler signature: `handler(task_ctx)` where `task_ctx` is a dict.
        The handler may:
        - perform work synchronously and return `None` or a dict like `{"status":..., "result":...}`;
        - be an `async def` coroutine function that returns the same; or
        - return an awaitable (then it will be awaited).

        The worker loop will normalize results and record activations. Callers
        may also provide a per-job override by setting `task_ctx['handler']`
        to a callable; that will take precedence over the registered handler.
        """
        self._job_handlers[role_name] = handler
    def start_executor(self, num_threads: int = 1) -> None:
        """Start background executor threads that will process the job queue.

        The executor respects each role's `max_parallel_jobs` when dispatching.
        """
        if self._executor_threads:
            return
        self._executor_stop.clear()
        # no shared async loop required for the simpler per-handler approach
        for _ in range(max(1, int(num_threads))):
            t = threading.Thread(target=self._worker_loop, daemon=True)
            self._executor_threads.append(t)
            t.start()

    def stop_executor(self, wait: bool = True) -> None:
        self._executor_stop.set()
        if wait:
            for t in list(self._executor_threads):
                t.join(timeout=2)
        self._executor_threads = []
        # no shared async loop to shutdown for the simpler approach

    def _worker_loop(self) -> None:
        while not self._executor_stop.is_set():
            job = None
            with self._queue_lock:
                # find a job that can run given role concurrency
                for idx, j in enumerate(self._job_queue):
                    role_name = j.get("role")
                    role = next((r for r in self._roles if r.name == role_name), None)
                    max_jobs = role.max_parallel_jobs if role is not None else 1
                    running = self._running_counts.get(role_name, 0)
                    if running < max_jobs:
                        job = self._job_queue.pop(idx)
                        break
            if job is None:
                time.sleep(0.01)
                continue

            role_name = job.get("role")
            task_ctx = job.get("task") or {}
            # increment running count
            with self._activations_lock:
                self._running_counts[role_name] = self._running_counts.get(role_name, 0) + 1
            # record running activation
            with self._activations_lock:
                self._activations.append({"role": role_name, "status": "running", "task": task_ctx})

            try:
                # allow per-job override: a callable supplied in task_ctx takes precedence
                override = task_ctx.get("handler") if isinstance(task_ctx, dict) else None
                handler = override if override is not None else self._job_handlers.get(role_name)
                if handler is not None:
                    # If handler is a coroutine function or returns an awaitable, run it
                    try:
                        if inspect.iscoroutinefunction(handler):
                            result = asyncio.run(handler(task_ctx))
                        else:
                            result = handler(task_ctx)
                            if inspect.isawaitable(result):
                                result = asyncio.run(result)

                        # allow handler to return a dict-like status
                        if isinstance(result, dict) and "status" in result:
                            with self._activations_lock:
                                self._activations.append({"role": role_name, "status": result.get("status"), "task": task_ctx, "result": result.get("result")})
                        else:
                            with self._activations_lock:
                                self._activations.append({"role": role_name, "status": "ok", "task": task_ctx, "result": result})
                    except Exception:
                        with self._activations_lock:
                            self._activations.append({"role": role_name, "status": "failed", "task": task_ctx})
                else:
                    # simulate execution: use simulate_duration if present, else estimate
                    duration = float(task_ctx.get("simulate_duration", 0))

                    if not duration:
                        # try to estimate via existing heuristic
                        try:
                            # find role descriptor
                            role = next((r for r in self._roles if r.name == role_name), None)
                            est = self._estimate(role, task_ctx) if role else 0
                            # cap to small value to avoid huge sleeps in tests
                            duration = min(est / 100.0, 0.5)
                        except Exception:
                            duration = 0.01

                    time.sleep(duration)
                    # mark completed
                    with self._activations_lock:
                        self._activations.append({"role": role_name, "status": "completed", "task": task_ctx})
            except Exception:
                with self._activations_lock:
                    self._activations.append({"role": role_name, "status": "failed", "task": task_ctx})
            finally:
                with self._activations_lock:
                    self._running_counts[role_name] = max(0, self._running_counts.get(role_name, 1) - 1)

    def _ensure_async_loop(self) -> None:
        """Create and start a shared asyncio event loop in a background thread."""
        if self._async_loop is not None and self._async_thread is not None:
            return

        def _run_loop(loop: asyncio.AbstractEventLoop):
            asyncio.set_event_loop(loop)
            loop.run_forever()
            try:
                loop.close()
            except Exception:
                pass

        loop = asyncio.new_event_loop()
        t = threading.Thread(target=_run_loop, args=(loop,), daemon=True)
        t.start()
        # wait briefly until loop is running
        timeout = 0.5
        start = time.time()
        while time.time() - start < timeout:
            if loop.is_running():
                break
            time.sleep(0.01)

        self._async_loop = loop
        self._async_thread = t

    def get_running_counts(self) -> Dict[str, int]:
        with self._activations_lock:
            return dict(self._running_counts)

    def get_job_queue(self) -> List[Dict[str, Any]]:
        return list(self._job_queue)
