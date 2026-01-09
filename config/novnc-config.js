/*
 * noVNC custom configuration
 * Sets default language to English and optimizes input settings
 */
(function() {
    // Set default language to English
    if (!localStorage.getItem('language')) {
        localStorage.setItem('language', 'en');
    }
    
    // Optimize input settings for better text selection
    if (!localStorage.getItem('cursor')) {
        localStorage.setItem('cursor', 'true');  // Show local cursor
    }
    
    // Set resize mode to remote for better resolution matching
    if (!localStorage.getItem('resize')) {
        localStorage.setItem('resize', 'remote');
    }
    
    // Enable clipboard sharing
    if (!localStorage.getItem('clipboard')) {
        localStorage.setItem('clipboard', 'true');
    }
    
    // ==========================================================================
    // E-ink / Low Latency Optimizations
    // ==========================================================================
    
    // Disable compression for lower latency (CPU time saved > network bytes on LAN)
    if (!localStorage.getItem('compression')) {
        localStorage.setItem('compression', '0');
    }
    
    // Lower quality for faster encoding (works well with e-ink grayscale)
    if (!localStorage.getItem('quality')) {
        localStorage.setItem('quality', '5');
    }
    
    // Use dot cursor for faster visual feedback on slow-refresh displays
    if (!localStorage.getItem('dotCursor')) {
        localStorage.setItem('dotCursor', 'true');
    }
    
    console.log('noVNC custom config loaded - language set to English, e-ink optimizations enabled');
})();
