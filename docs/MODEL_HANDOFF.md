# ML Model Handoff Architecture

## Principles

- All models must be evaluated against strict memory bounds (`< 200MB` peak during inference) to ensure stable background operations.
- Inter-layer communication for model tracking should be heavily decoupled and dependency injected.
- Any model addition or swap requires updating this document with new benchmark results.

## Task Tracking

- **Completed:** S001 + S001B + S002/D/E/F/G (Core pipeline) merged to main. Tagged `v2.0.0-core-trim-export`.
- **QA_PENDING:** S003 (Export Studio + UI Polish) — Dark cinematic theme, gradient home, export settings sheet (resolution/FPS/quality), Save Copy mode.

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`
