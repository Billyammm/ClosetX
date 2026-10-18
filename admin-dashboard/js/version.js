async function displayDashboardVersion() {
    const versionLabels = [
        document.getElementById('dashboard-version'),
        document.getElementById('login-dashboard-version'),
    ].filter(Boolean);
    if (versionLabels.length === 0) return;

    try {
        const response = await fetch('VERSION', { cache: 'no-store' });
        if (!response.ok) {
            throw new Error(`Could not load dashboard version (HTTP ${response.status}).`);
        }

        const version = (await response.text()).trim();
        if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
            throw new Error('The dashboard VERSION file does not contain a valid semantic version.');
        }

        versionLabels.forEach((label) => {
            label.textContent = `v${version}`;
        });
    } catch (error) {
        console.error('Unable to display dashboard version:', error);
        versionLabels.forEach((label) => {
            label.textContent = 'Version unavailable';
        });
    }
}

displayDashboardVersion();
