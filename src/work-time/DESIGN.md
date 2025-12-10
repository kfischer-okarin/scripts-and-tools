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
| `worktime status [DATE] [--json]` | Show current state + projections (optional: YYYY-MM-DD) |
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
Work today: 3:00
Today's surplus: -5:00
Month surplus: -6:00
Remaining lunch: 60m
Projected end: 18:00
End for zero surplus: 19:00
```

- **State**: unstarted/working/on_break/on_lunch/stopped
- **Remaining lunch**: Minutes left of the 60-minute lunch allowance (60 if not taken, decreases while on lunch, 0 after full hour used)
- **Projected end**: Time to complete 8 hours (adds 1hr if lunch not taken)
- **End for zero surplus**: Time to reach 0 month surplus (accounts for previous days)

With `--json` flag:

```json
{
  "state": "working",
  "work_minutes": 180,
  "todays_surplus_minutes": -300,
  "month_surplus_minutes": -360,
  "remaining_lunch_break_minutes": 60,
  "projected_end_time": "2024-12-10T18:00:00+09:00",
  "projected_end_time_for_zero_surplus": "2024-12-10T19:00:00+09:00"
}
```

## Month Output

```
Month: 2024-12
Date             | Work     | Surplus
-----------------------------------------
2024-12-10 (Tue) |     8:00 |   +0:00
2024-12-11 (Wed) |     7:00 |   -1:00
-----------------------------------------
Total surplus: -1:00
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
- `OutsideWorkingHoursError` - stop/break/lunch when outside working hours
- `LunchAlreadyTakenError` - lunch toggle after lunch completed
