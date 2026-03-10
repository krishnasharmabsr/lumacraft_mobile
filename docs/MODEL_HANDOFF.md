# ML Model Handoff Architecture

## Principles

- All models must be evaluated against strict memory bounds (`< 200MB` peak during inference) to ensure stable background operations.
- Inter-layer communication for model tracking should be heavily decoupled and dependency injected.
- Any model addition or swap requires updating this document with new benchmark results.

## Task Tracking

- **Completed:** S001 + S001B merged.
- **QA_PENDING:** S002/B/C/D/E (Core pipeline + Native import fix) - Import uses native Kotlin MethodChannel (zero plugin deps). Preview trim auto-pauses at end. Negative trim validated.

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`
