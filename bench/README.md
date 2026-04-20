# Benchmark

Benchmark harness for comparing Lua ECS libraries.

> If a library requires Luau syntax, use the [luau variant](https://github.com/napHiwka/luau-ecs-benchmarks) of this benchmark instead.

## Run

```bash
lua bench/init.lua
```

Results are printed to the console. For each adapter you will see per-run scenario timings, checksums, memory deltas, and aggregated statistics (mean, p50, p90, p95, min, max) across all runs.

## Configuration

Edit the config table at the `bench/config.lua`. Key options:

| Option | Default | Description |
|---|---|---|
| `execution.runsPerAdapter` | — | How many times each adapter is run; results are aggregated |
| `execution.includeStressScenarios` | — | Toggle stress workloads on or off |
| `garbageCollection.collectBeforeScenario` | — | Force a GC cycle before each scenario |
| `garbageCollection.collectAfterScenario` | — | Force a GC cycle after each scenario |

Settings are grouped under: `execution`, `garbageCollection`, `dataset`, `queryWorkloads`, `mutationWorkloads`, `stress`.

## Workloads

**Normal**
- Entity creation
- Component updates
- Add/remove structural changes
- Random component reads
- 1-, 3-, and wide-component query iteration
- Work-style scenario: 24 overlapping queries with per-frame writes

**Stress** can be enabled via config; expose pathological cases and theoretical limits, not typical usage.

## Adding an Adapter

Create a file in `bench/adapters/` that returns a factory function. The function receives the library module and must return an adapter table.

### Required fields

| Field | Description |
|---|---|
| `name` | String identifier shown in output |
| `note` | Notable caveats or implementation details affecting result interpretation |
| `createContext()` | Creates and returns a context table (world, registry, etc). Called once before each scenario |
| `createEntity(context)` | Allocates and returns an entity with no components |
| `allocComponent(context, index)` | Allocates one component type. `index` is a unique integer. Called once per component during setup, outside the timed section |
| `set(context, entity, component, value)` | Assigns a numeric `value` to `component` on `entity` |
| `get(context, entity, component)` | Returns the current numeric value of `component` on `entity` |
| `has(context, entity, component)` | Returns truthy if `entity` has `component`, falsy otherwise |
| `remove(context, entity, component)` | Removes `component` from `entity` |
| `query(context, components)` | Returns matching entities. Accepts two formats (auto-detected on first call): |
| | **Iterator** — a function returning `entity, v1, v2, ...` per call, `nil` when exhausted |
| | **Array** — a table of rows `{ entity, v1, v2, ... }` |

Component values in `query` results must appear in the same order as the `components` input array.

### Optional hooks

| Field | Description |
|---|---|
| `makeEntityData(context, components, blueprint)` | Converts a blueprint into the data table used by the spawn loop. Override when your library needs a custom representation for bulk creation. Default: `{ [componentHandle] = value, ... }` |
| `spawn(context, data)` | Creates one entity from a pre-built data table. Override when your library has an efficient batch-creation API. Default: `createEntity` + `set` per component |

> Keep adapters thin.
