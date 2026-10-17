const closetxThemeStorageKey = 'closetx-admin-theme';

function applyClosetXTheme(theme) {
    const isDark = theme === 'dark';
    document.documentElement.dataset.theme = isDark ? 'dark' : 'light';

    const toggle = document.getElementById('theme-toggle');
    if (toggle) {
        toggle.setAttribute('aria-label', `Switch to ${isDark ? 'light' : 'dark'} mode`);
        toggle.setAttribute('title', `Switch to ${isDark ? 'light' : 'dark'} mode`);
        toggle.querySelector('.theme-toggle-icon').className = `theme-toggle-icon fas fa-${isDark ? 'sun' : 'moon'}`;
        toggle.querySelector('.theme-toggle-label').textContent = isDark ? 'Light mode' : 'Dark mode';
    }

    document.dispatchEvent(new CustomEvent('closetx-theme-change', { detail: { theme } }));
}

function getClosetXTheme() {
    try {
        return localStorage.getItem(closetxThemeStorageKey) === 'dark' ? 'dark' : 'light';
    } catch (error) {
        console.warn('Could not load the saved admin dashboard theme:', error);
        return 'light';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    applyClosetXTheme(getClosetXTheme());

    document.getElementById('theme-toggle')?.addEventListener('click', () => {
        const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
        applyClosetXTheme(theme);
        try {
            localStorage.setItem(closetxThemeStorageKey, theme);
        } catch (error) {
            console.warn('Could not save the admin dashboard theme:', error);
        }
    });
});
