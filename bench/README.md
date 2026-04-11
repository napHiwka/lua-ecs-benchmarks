# Benchmarks

This folder contains the benchmark harness used to compare ECS libraries.

If a target library requires Luau syntax, run it under a [luau variant](https://github.com/napHiwka/luau-ecs-benchmarks) of this benchmark.

## Run

```bash
lua bench/init.lua
```

## Adapter Contract

To add another ECS, create a file in `bench/adapters` that returns a factory function that receives the library module and returns an adapter table.

### Required fields

**`name`** - string identifier shown in benchmark output.

**`note`** - string describing notable implementation details or caveats that affect how results should be interpreted.

**`createEntity(context)`** - allocates and returns an entity with no components.

**`createContext()`** - creates and returns a context table. The context is passed to every other adapter function and should hold whatever the library needs (world, registry, etc). Called once before each scenario.

**`allocComponent(context, index)`** - allocates and returns one component type. `index` is a unique integer per component. Called once per component during setup, outside the timed section.

**`set(context, entity, component, value)`** - assigns `value` (always a number) to `component` on `entity`.

**`get(context, entity, component)`** - returns the current numeric value of `component` on `entity`.

**`has(context, entity, component)`** - returns a truthy value if `entity` currently has `component`, falsy otherwise.

**`remove(context, entity, component)`** - removes `component` from `entity`.

**`query(context, components)`** - `components` is an array of component handles allocated by `allocComponent`. Returns matching entities with their component values in one of two formats:

- ***Iterator*** - a function that on each call returns `entity, v1, v2, ...` for the next matching entity, and `nil` when exhausted. Component values must appear in the same order as `components`.
- ***Array*** - a table where each element is a row table `{ entity, v1, v2, ... }`. Component values must appear in the same order as `components`, starting at index 2.

Benchmark auto-detects the format on the first call and dispatches accordingly.

### Optional hooks

**`makeEntityData(context, components, blueprint)`** - converts a blueprint into a data table used by the spawn loop. If omitted, the default implementation produces `{ [componentHandle] = value, ... }`. Override when your library needs a different representation during bulk entity creation.

**`spawn(context, data)`** - creates one entity from a pre-built data table and returns it. If omitted, the harness falls back to calling `createEntity` followed by `set` for each component. Implement this when your library has a more efficient batch-creation API.

### Rule

> Keep adapters thin.

## Configuration

Settings are grouped into sections:

* `execution`
* `garbageCollection`
* `dataset`
* `queryWorkloads`
* `mutationWorkloads`
* `stress`

Notable options:

* `execution.runsPerAdapter`
* `execution.includeStressScenarios`
* `garbageCollection.collectBeforeScenario`
* `garbageCollection.collectAfterScenario`

## Console Output

For each adapter, the harness prints:

* adapter name
* adapter note
* each run's scenario timings, checksums, verification fingerprint, and memory delta
* aggregated timing statistics across runs

Aggregated timing includes:

* mean
* p50
* p90
* p95
* min
* max

## Workloads

Normal workloads include:

* entity creation
* updating existing components
* add/remove structural changes
* random component reads
* 1-component query iteration
* 3-component query iteration
* wide query iteration
* a work-style scenario with 24 overlapping queries plus writes per frame

Stress workloads remain available and can be disabled with config.
