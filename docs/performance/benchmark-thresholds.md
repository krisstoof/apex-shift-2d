# Benchmark thresholds

Benchmark thresholds are used to detect clear performance regressions in the Apex Shift 2D prototype.

Local runs report threshold violations as warnings by default. CI or explicit validation runs can fail on threshold violations by setting:

```text
APEX_BENCHMARK_FAIL_ON_REGRESSION=1
```

or by passing:

```text
--benchmark-fail-on-regression
```

Thresholds are configured in:

```text
res://config/benchmark_thresholds.json
```

## How to read validation

- `passed` means the collected benchmark stayed within the configured thresholds.
- `warning` means one or more metrics exceeded a threshold, but fail mode was not enabled.
- `failed` means one or more metrics exceeded a threshold while fail mode was enabled.

The validation report lists each metric, its actual value, the threshold, and the direction of the comparison.

## Threshold philosophy

The initial thresholds are conservative. They are meant to catch obvious regressions in:

- average FPS
- frame time spikes
- hitch counts
- texture rebuild churn
- active resource collision pressure
- scene/node pressure

These values should be calibrated over time as the prototype evolves.
