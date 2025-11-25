## Tool script to export all training sequences to .tres resource files
##
## Usage:
##   1. Open this script in Godot Editor
##   2. Click "Run" (Ctrl/Cmd+Shift+X) or add to scene and run
##   3. Check output console for results
##   4. Resource files will be created in res://resources/training_sequences/
##
## This migration script converts hardcoded training sequences into
## external .tres resource files for easier editing and version control.
@tool
extends SceneTree

func _initialize() -> void:
	print("\n" + "=".repeat(70))
	print("Training Sequence Export Tool")
	print("=".repeat(70))

	# Ensure SequenceLibrary is available
	if not ClassDB.class_exists("SequenceLibrary"):
		push_error("SequenceLibrary class not found!")
		quit(1)
		return

	# Export all sequences
	print("\nExporting training sequences to resource files...")
	var results: Dictionary = SequenceLibrary.export_all_sequences(false)

	# Display results
	print("\n" + "-".repeat(70))
	print("Export Results:")
	print("-".repeat(70))

	if results.success.size() > 0:
		print("\n✓ Successfully exported (%d):" % results.success.size())
		for seq_id in results.success:
			var path := SequenceLibrary.get_sequence_path(seq_id)
			print("  • %s → %s" % [seq_id, path])

	if results.skipped.size() > 0:
		print("\n○ Skipped (already exist) (%d):" % results.skipped.size())
		for seq_id in results.skipped:
			var path := SequenceLibrary.get_sequence_path(seq_id)
			print("  • %s → %s" % [seq_id, path])

	if results.failed.size() > 0:
		print("\n✗ Failed (%d):" % results.failed.size())
		for seq_id in results.failed:
			print("  • %s" % seq_id)

	# Summary
	var total := results.success.size() + results.skipped.size() + results.failed.size()
	print("\n" + "=".repeat(70))
	print("Summary: %d/%d sequences ready" % [results.success.size() + results.skipped.size(), total])
	print("=".repeat(70))

	# Display next steps
	print("\nNext Steps:")
	if results.success.size() > 0:
		print("  1. Check res://resources/training_sequences/ for exported files")
		print("  2. Commit the new .tres files to version control")
		print("  3. Training sequences will now load from files instead of code")
	else:
		print("  All sequences already exported!")

	print("\nTo re-export (overwrite existing files):")
	print("  Call SequenceLibrary.export_all_sequences(true)")
	print("")

	# Exit with appropriate code
	var exit_code := 0 if results.failed.size() == 0 else 1
	quit(exit_code)
