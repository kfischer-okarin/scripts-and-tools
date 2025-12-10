# Work Time CLI - Design Document

## Overview
Ruby CLI for tracking worktime and breaks for employer timesheet reporting.

## Commands

| Command | Description |
|---------|-------------|
| `worktime start` | Start work session (warns if already working) |
| `worktime stop` | Stop work (auto-ends any active break) |
| `worktime lunch` | Toggle lunch break (1/day, 1hr allotment) |
| `worktime break` | Toggle regular break |
| `worktime status` | Show current state + projections |
| `worktime month [YYYY-MM]` | Monthly overview table |
| `worktime set-hours HOURS [--date DATE]` | Override expected hours |

## Business Rules

- All breaks deduct from work time
- Lunch: one per day, 1-hour fixed allotment, track remaining time
- Default expected hours: 8/day (overridable per day)
- Surplus resets monthly (no carryover)
- Can't start break without active work
- Stop auto-ends any active break

## Status Output

- Current state (working/break/lunch/stopped)
- Today's projected end time (adds 1hr if before lunch)
- Current surplus/minus if stopped now
- End time needed to reach 0 surplus/minus

## Month Output

- Table: date | work duration | daily surplus/minus
- Total surplus at end

## Architecture (Humble Objects)

```
Thor CLI (thin, untested)
    │
    ▼
Domain Layer (tested)
    ├── WorktimeTracker (orchestrator)
    ├── DayLog (single day's events)
    ├── MonthLog (collection of DayLogs)
    ├── StatusCalculator (projections)
    └── Result objects (plain data)
```

Thor only: parses args, calls domain, formats output from Result objects.

## Data Format

**Location**: `~/.local/share/worktime/`

**Event data** (per month): `YYYY-MM.csv`
```csv
date,event,time
2024-12-10,start,09:00
2024-12-10,lunch_start,12:30
2024-12-10,lunch_end,13:15
2024-12-10,break_start,15:00
2024-12-10,break_end,15:10
2024-12-10,stop,17:30
```

**Overrides** (per month): `YYYY-MM-worktime-overrides.csv`
```csv
date,expected_hours
2024-12-25,0
2024-12-31,4
```

## File Structure

```
src/work-time/
├── Gemfile
├── mise.toml
├── bin/
│   └── worktime              # Executable entry point
├── lib/
│   └── worktime/
│       ├── cli.rb            # Thor wrapper (thin)
│       ├── tracker.rb        # Main orchestrator
│       ├── day_log.rb        # Single day's events
│       ├── month_log.rb      # Month collection + persistence
│       ├── status_calculator.rb
│       ├── event.rb          # Event value object
│       └── results/
│           ├── status_result.rb
│           └── month_result.rb
└── test/
    ├── test_helper.rb
    ├── tracker_test.rb
    ├── day_log_test.rb
    ├── month_log_test.rb
    └── status_calculator_test.rb
```

## Implementation Steps (TDD)

### Phase 1: Core Domain
1. `Event` value object - represents a timestamped event
2. `DayLog` - add events, calculate work duration, break duration, lunch tracking
3. `MonthLog` - load/save CSV, collection of DayLogs, overrides handling

### Phase 2: Calculations
4. `StatusCalculator` - current state, projections, surplus/minus
5. Result objects - `StatusResult`, `MonthResult`

### Phase 3: Orchestration
6. `Tracker` - coordinates operations, validates state transitions

### Phase 4: CLI
7. Thor CLI wrapper - thin layer calling Tracker, formatting Results
8. Executable `bin/worktime`

### Phase 5: Polish
9. Edge case handling, error messages
10. Manual testing and refinement
