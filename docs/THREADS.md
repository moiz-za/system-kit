# THREADS.md — [PROJECT NAME] Concurrency Registry

> Live registry of running threads. Every thread registers before working.
> This file IS the lock store — claims written here are binding.

---

## Protocol

1. **REGISTER** before working: add your row below with task + mutexes + shared files.
2. **MUTEXES:**
   - `CODE` = exclusive right to edit source files (one thread at a time)
   - `LEDGER` = short hold on shared tracking files (append-only edits only)
   - `DB-CF` = database/schema/cloud-infrastructure changes
3. **OWNERSHIP:** claimed task gives exclusive write to its checkpoint, its task row,
   and its plan sections. Never touch another live thread's owned files.
4. **SHARED LEDGERS:** append-only edits of own rows only. Restructures need ALL-CLEAR.
5. **STALE RECLAMATION:** >4h no heartbeat → flag → anyone may reclaim after flagging.
6. **DEREGISTER** when done. Never deregister another live thread.

## Active Threads

| Thread | Started | Tasks | Mutexes | Shared Files | Heartbeat | Status |
|---|---|---|---|---|---|---|

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
