Learning Julia by programming usual computations over Boolean networks

Comments welcome :-)

## Implemented feaures

### Fully-asynchronous simulation

Compute probabilities of reachable attractors using random walk using the fully
asynchronous update mode (one node updated at a time).

See `examples/fasync_tumour_invasion.jl`:
```sh
julia --project=. examples/fasync_tumour_invasion.jl
```
The implementation supports threads:
```sh
julia -t auto --project=. examples/fasync_tumour_invasion.jl
```
