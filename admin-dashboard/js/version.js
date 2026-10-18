async function displayDashboardVersion() {
    const versionLabel = document.getElementById('dashboard-version');
    if (!versionLabel) return;

    try {
        const response = await fetch('VERSION', { cache: 'no-store' });
        if (!response.ok) {
            throw new Error(`Could not load dashboard version (HTTP ${response.status}).`);
        }

        const version = (await response.text()).trim();
        if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
            throw new Error('The dashboard VERSION file does not contain a valid semantic version.');
        }

        versionLabel.textContent = `v${version}`;
    } catch (error) {
        console.error('Unable to display dashboard version:', error);
        versionLabel.textContent = 'Version unavailable';
    }
}

displayDashboardVersion();
