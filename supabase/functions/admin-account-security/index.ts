import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(500, { error: 'Account security is not configured on the server.' });
  }
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return jsonResponse(401, { error: 'Sign in as a ClosetX administrator.' });
  }
  const token = authorization.slice('Bearer '.length);
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) return jsonResponse(401, { error: 'Your session is invalid or expired.' });
  if (user.app_metadata?.closetx_admin !== true) {
    return jsonResponse(403, { error: 'Only a ClosetX administrator can access account alerts.' });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (request.method === 'POST') {
    let body: { action?: unknown; userId?: unknown };
    try { body = await request.json(); } catch {
      return jsonResponse(400, { error: 'Request body must be valid JSON.' });
    }
    if (body.action === 'list') {
      const { data, error } = await adminClient
        .from('admin_notifications')
        .select('id, type, user_id, username, email, ip_address, status, created_at, resolved_at')
        .order('created_at', { ascending: false })
        .limit(100);
      if (error) return jsonResponse(500, { error: 'Could not load account alerts.' });
      return jsonResponse(200, { notifications: data ?? [] });
    }
    if (body.action !== 'unlock'
      || typeof body.userId !== 'string'
      || !/^[0-9a-f-]{36}$/i.test(body.userId)) {
      return jsonResponse(400, { error: 'A valid account unlock request is required.' });
    }
    const { error } = await adminClient.rpc('admin_unlock_account', {
      p_target_user_id: body.userId,
    });
    if (error) return jsonResponse(403, { error: 'Could not unlock the account.' });
    return jsonResponse(200, { success: true });
  }

  return jsonResponse(405, { error: 'Method not allowed.' });
});
