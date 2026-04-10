# Benchmarks

This folder contains the benchmark harness used to compare ECS libraries.

If a target library requires Luau syntax, run it under a [luau variant](https://github.com/napHiwka/luau-ecs-benchmarks) of this benchmark.

## Run

```bash
lua bench/init.lua
```

## Adapter Contract

To add another ECS, create a file in `bench/adapters` that returns a factory:

* `name`
* `note`
* `createContext()`
* `allocComponent(context, index)`
* `set(context, entity, component, value)`
* `get(context, entity, component)`
* `has(context, entity, component)`
* `remove(context, entity, component)`
* `query(context, components)`

Optional hooks:

* `makeEntityData(context, components, blueprint)`
* `spawn(context, data)`
* `createEntity(context)`

The adapter file receives the library module as its argument.

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

## Fairness Notes

* All adapters receive the same workload spec derived from one seed.
* Verification is outside the timed region.
* Query reuse policy is adapter-specific and must be disclosed through the adapter `note`.
* Wide-query and work-style scenarios are included alongside simpler scenarios so results are not dominated by one synthetic pattern.
