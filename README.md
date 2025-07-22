# OilReservoirBench

Egg model, oil reservoir optimization benchmark for research.

## Info for egg model

- (paper) The egg model – a geological ensemble for reservoir simulation
- (example) [MRST egg model manual](https://www.sintef.no/contentassets/2551f5f85547478590ceca14bc13ad51/ad-blackoil.html#example-demonstrating-the-two-phase-oil-water-egg-model)

## Info for MRST

- [oil reservior](https://github.com/hao12312/reservoir-simulation?tab=readme-ov-file) repo

## Change to the mrst-2024b
- max iteration 25->50
- cutting time step 0.5->0.25
- Add the amgcl nonlinearsolver for fast solving

## What to do for a research study
- Methodolody focus on the optimization no need for a 10 year simulation
- Ref: Aghayev et al. - 2025 - Surrogate-Assisted Optimization of Highly Constrained Oil Recovery Processes Using Classification-Ba
    - 0.5 year horizon with weekly adjustment for 12 wells, resulting in 312 dims variables. Reduce the dims with function control method, resulting in three function, so the parameters is 3 * 12 = 36

## The usage for the egg model
- [egg model example](https://www.sintef.no/contentassets/2551f5f85547478590ceca14bc13ad51/ad-blackoil.html#example-demonstrating-the-two-phase-oil-water-egg-model)


## How to use this self-contained oil reservoir benchmark
- Run setup_benchmark.m
- Run runOilReservoirBenchmark.m