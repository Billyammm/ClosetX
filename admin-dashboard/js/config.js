const SUPABASE_URL = 'https://pdeywqyobsefgwycevwf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkZXl3cXlvYnNlZmd3eWNldndmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNDI0MzQsImV4cCI6MjA5MjYxODQzNH0.1Vxf7-2uZpqEpZn71s6eZknli58rgAzcGwhc_MSFhqI';

const closetxSupabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

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
