# Lua ECS Benchmarks

This repository is dedicated to evaluating and comparing various Entity Component System (ECS) implementations in Lua. Its primary purpose is exploratory: to provide a controlled environment for running benchmarks and observing performance characteristics across different libraries. This project does not include precomputed results, visualizations, or performance summaries. Users are expected to run the benchmarks locally to obtain relevant and current data.

## Quick Start

```bash
# 1. Download libraries
python bootstrap/main.py

# 2. Run benchmarks
lua bench/init.lua
```

See [`bootstrap/README.md`](bootstrap/README.md) and [`bench/README.md`](bench/README.md) for full details.

### Included libraries

* [concord](https://github.com/Keyslam-Group/Concord)
* [ecs-lua](https://github.com/nidorx/ecs-lua)
* [evolved](https://github.com/BlackMATov/evolved.lua)
* [lovetoys](https://github.com/lovetoys/lovetoys)
* [rune](https://github.com/jamesstidard/rune)
* [tiny-ecs](https://github.com/bakpakin/tiny-ecs)
* [ecs-lib](https://github.com/liuhaopen/ecs.git)
* [alecs](https://github.com/pcornier/Alecs)

## Interpretation of Results

Benchmark results should be interpreted with caution. Performance outcomes are highly sensitive to usage patterns, architectural decisions, and implementation details. A given ECS framework may perform poorly or exceptionally well depending on how it is applied.

It is important to recognize that tools are frequently misused. Suboptimal results are often a consequence of incorrect or inefficient usage rather than inherent limitations of the library itself. In many cases, performance bottlenecks originate in application-level code rather than in the ECS framework.

## On Stress Benchmarks

The included benchmarks are intentionally stress-oriented. These scenarios are not designed to represent typical production workloads. Instead, they illustrate edge cases and failure modes, often highlighting what happens under inefficient or extreme usage patterns.

Such benchmarks can be useful for identifying theoretical limits or pathological cases, but they should not be treated as predictors of real-world performance.

## Practical Guidance

When evaluating ECS solutions using this repository:

- Run benchmarks in your own environment under conditions that resemble your target use case.
- Avoid drawing conclusions from isolated metrics.
- Consider code structure, data access patterns, and system design alongside raw benchmark numbers.
- Treat results as indicative rather than definitive.
