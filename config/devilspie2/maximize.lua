-- =============================================================================
-- Devilspie2 Configuration - Auto-maximize all windows
-- =============================================================================
-- This script runs for every new window that opens and maximizes it

debug_print("Window opened: " .. get_window_name())
debug_print("Application: " .. get_application_name())

-- Maximize all windows when they open
maximize()
