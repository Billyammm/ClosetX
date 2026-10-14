let closetxSupabase;

const closetxSupabaseReady = (async () => {
    let response = await fetch('../supabase.env.json', { cache: 'no-store' });
    if (response.status === 404) {
        response = await fetch('/api/config', { cache: 'no-store' });
    }
    if (!response.ok) {
        throw new Error('Could not load the ClosetX Supabase configuration. Check the dashboard setup and deployment environment variables.');
    }

    const config = await response.json();
    const url = config.SUPABASE_URL?.trim();
    const anonKey = config.SUPABASE_ANON_KEY?.trim();
    if (!url || !anonKey || url.includes('YOUR_PROJECT_REF') || anonKey.includes('PASTE_YOUR')) {
        throw new Error('Set SUPABASE_URL and SUPABASE_ANON_KEY in the project root supabase.env.json.');
    }

    closetxSupabase = window.supabase.createClient(url, anonKey);
    return closetxSupabase;
})();

async function isClosetXAdmin() {
    const { data, error } = await closetxSupabase.rpc('is_closetx_admin');
    if (error) throw error;
    return data === true;
}

async function logout() {
    if (!window.confirm('Are you sure you want to sign out?')) return;

    const { error } = await closetxSupabase.auth.signOut();
    if (error) {
        console.error('Sign-out failed:', error);
        window.alert(`Could not sign out: ${error.message}`);
        return;
    }

    window.location.replace('login.html');
}
