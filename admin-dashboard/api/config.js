module.exports = (request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    response.setHeader('X-Content-Type-Options', 'nosniff');

    if (request.method !== 'GET') {
        response.setHeader('Allow', 'GET');
        response.statusCode = 405;
        response.end(JSON.stringify({ error: 'Method not allowed.' }));
        return;
    }

    const url = process.env.SUPABASE_URL?.trim();
    const anonKey = process.env.SUPABASE_ANON_KEY?.trim();

    if (!url || !anonKey) {
        response.statusCode = 500;
        response.end(JSON.stringify({
            error: 'Set SUPABASE_URL and SUPABASE_ANON_KEY in the Vercel project environment.',
        }));
        return;
    }

    let keyRole;
    try {
        keyRole = JSON.parse(Buffer.from(anonKey.split('.')[1], 'base64url').toString()).role;
    } catch {
        keyRole = null;
    }
    if (anonKey.startsWith('sb_secret_') || keyRole === 'service_role') {
        response.statusCode = 500;
        response.end(JSON.stringify({
            error: 'SUPABASE_ANON_KEY must be a publishable or anon key, not a service-role key.',
        }));
        return;
    }

    let parsedUrl;
    try {
        parsedUrl = new URL(url);
    } catch {
        response.statusCode = 500;
        response.end(JSON.stringify({ error: 'The Vercel Supabase URL is invalid.' }));
        return;
    }

    if (parsedUrl.protocol !== 'https:') {
        response.statusCode = 500;
        response.end(JSON.stringify({ error: 'The Vercel Supabase URL must use HTTPS.' }));
        return;
    }

    response.statusCode = 200;
    response.end(JSON.stringify({
        SUPABASE_URL: parsedUrl.origin,
        SUPABASE_ANON_KEY: anonKey,
    }));
};
