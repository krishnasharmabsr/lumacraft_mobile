# ML Model Handoff Architecture

## Principles

- All models must be evaluated against strict memory bounds (`< 200MB` peak during inference) to ensure stable background operations.
- Inter-layer communication for model tracking should be heavily decoupled and dependency injected.
- Any model addition or swap requires updating this document with new benchmark results.

## Task Tracking

- **Completed:** S001 + S001B merged.
- **Next Task:** S002 (Core video pipeline: import -> preview -> trim -> export)
