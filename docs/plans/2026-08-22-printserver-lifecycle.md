# Permanent Print Server Lifecycle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate recurring print-server outages caused by competing manual and LaunchAgent instances.

**Architecture:** Make launchd the only process owner. Route one-click recovery through a controller that resets the job, safely removes an orphaned listener, reloads the checked-in plist, and waits for port 8632.

**Tech Stack:** POSIX shell, macOS launchd, ippeveprinter, shell integration tests.

### Task 1: Specify lifecycle behavior

**Files:**
- Create: `tests/test-printserver-control.sh`

1. Write fake-command tests for lifecycle ordering, safe orphan selection, and timeout reporting.
2. Run `bash tests/test-printserver-control.sh` and verify it fails because `harness/printserver-control.sh` does not exist.

### Task 2: Implement the single-owner controller

**Files:**
- Create: `harness/printserver-control.sh`
- Create: `launchd/com.foozio.g2010.printserver.plist`

1. Implement `restart` and `status` commands with overridable paths for tests.
2. Unload before orphan cleanup; bootstrap and kickstart only after the port is free.
3. Poll readiness with a bounded timeout and useful log output.
4. Run `bash tests/test-printserver-control.sh` and verify all tests pass.

### Task 3: Remove the competing manual owner

**Files:**
- Modify: `G2010-PrintServer.command`

1. Add a failing assertion that the Desktop command delegates to the controller and contains no `nohup` or direct `ippeveprinter` process management.
2. Run the test and observe the expected failure.
3. Replace the command body with controller delegation.
4. Run the full shell test and verify it passes.

### Task 4: Document and verify the live repair

**Files:**
- Modify: `README.md`
- Modify: `docs/03-OPERATIONS.md`
- Modify: `docs/04-TROUBLESHOOTING.md`

1. Update operations and troubleshooting guidance to describe the single-owner model.
2. Run shell syntax checks and lifecycle tests.
3. Install/reset the real LaunchAgent using the controller.
4. Confirm exactly one listener on port 8632 and an active launchd job.
5. Submit a generated one-page PDF and confirm the IPP, raster, Gutenprint, and USB logs are reached.
