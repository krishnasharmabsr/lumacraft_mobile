/// The active editing tool currently open in the editor toolbar.
///
/// Moving this out of EditorScreen into its own file gives it a stable
/// import path for future extension (e.g. from domain layer or tests).
enum EditorTool { none, trim, filters, speed, canvas, crop }
