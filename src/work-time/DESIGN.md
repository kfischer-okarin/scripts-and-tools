# Work Time CLI - Design Document

## Overview

Ruby CLI for tracking worktime and breaks for employer timesheet reporting.

## Commands

| Command | Description |
|---------|-------------|
| `worktime start` | Start work session (warns if already working) |
| `worktime stop` | Stop work (auto-ends any active break) |
| `worktime lunch` | Toggle lunch break (1/day) |
| `worktime break` | Toggle regular break |
| `worktime status [DATE]` | Show current state + projections (optional: YYYY-MM-DD) |
| `worktime month [MONTH]` | Monthly overview table (optional: YYYY-MM) |
| `worktime set_hours HOURS [--date DATE]` | Override expected hours |

## Business Rules

- All breaks (lunch + regular) deduct from work time
- Lunch: one per day, tracked separately for 1-hour allotment
- Default expected hours: 8/day (overridable per day)
- Surplus resets monthly (no carryover)
- Can't start break without active work
- Stop auto-ends any active break

## Status Output

```
State: working
Work today: 3h 00m
Today's surplus: -5h 00m
Month surplus: -6h 00m
Projected end: 18:00
End for zero surplus: 19:00
```

- **State**: working/on_break/on_lunch/stopped
- **Projected end**: Time to complete 8 hours (adds 1hr if lunch not taken)
- **End for zero surplus**: Time to reach 0 month surplus (accounts for previous days)

## Month Output

```
Month: 2024-12
Date       | Work     | Surplus
-----------------------------------
2024-12-10 |   8h 00m |  +0h 00m
2024-12-11 |   7h 00m |  -1h 00m
-----------------------------------
Total surplus: -1h 00m
```

## Architecture

```
Thor CLI (thin, untested)
    │
    ▼
Tracker (domain logic, tested)
    ├── Status (Data object)
    ├── DayStats (Data object)
    └── MonthStats (Data object)
```

- **CLI**: Parses args, sets `now` time, calls Tracker, formats output
- **Tracker**: All domain logic, CSV persistence, calculations
- **Data objects**: Plain `Data.define` structs for results

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
├── Rakefile
├── mise.toml
├── DESIGN.md
├── exe/
│   └── worktime              # Executable entry point
├── lib/
│   └── worktime/
│       ├── cli.rb            # Thor CLI (thin wrapper)
│       └── tracker.rb        # Domain logic + persistence
└── test/
    ├── test_helper.rb
    └── tracker_test.rb
```

## Error Handling

Exceptions raised by Tracker, caught and displayed by CLI:

- `AlreadyWorkingError` - start when already working
- `NotWorkingError` - stop/break/lunch when not working
- `LunchAlreadyTakenError` - lunch toggle after lunch completed
