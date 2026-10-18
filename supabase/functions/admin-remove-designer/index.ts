import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed.' });
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return jsonResponse(401, { error: 'Sign in as a ClosetX administrator.' });
  }

  let body: { designerId?: unknown };
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }
  if (typeof body.designerId !== 'string'
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.designerId)) {
    return jsonResponse(400, { error: 'A valid designer account ID is required.' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Required Supabase Edge Function environment variables are missing.');
    return jsonResponse(500, { error: 'Account removal is not configured on the server.' });
  }

  const token = authorization.slice('Bearer '.length);
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse(401, { error: 'Your session is invalid or expired. Sign in again.' });
  }
  if (user.app_metadata?.closetx_admin !== true) {
    return jsonResponse(403, { error: 'Only a ClosetX administrator can remove designer accounts.' });
  }
  if (user.id === body.designerId) {
    return jsonResponse(400, { error: 'You cannot remove your own account.' });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('id, role')
    .eq('id', body.designerId)
    .maybeSingle();
  if (profileError) {
    console.error('Could not look up designer profile:', profileError);
    return jsonResponse(500, { error: 'Could not verify the designer account.' });
  }
  if (!profile || profile.role !== 'designer') {
    return jsonResponse(404, { error: 'Designer account not found.' });
  }

  const { data: target, error: targetError } = await adminClient.auth.admin.getUserById(body.designerId);
  if (targetError) {
    console.error('Could not look up designer Auth account:', targetError);
    return jsonResponse(500, { error: 'Could not verify the designer Auth account.' });
  }
  if (target.user?.app_metadata?.closetx_admin === true) {
    return jsonResponse(403, { error: 'Administrator accounts cannot be removed from the Designers page.' });
  }

  const storage = adminClient.storage.from('design-images');
  const paths: string[] = [];
  const folders = [body.designerId];
  while (folders.length) {
    const folder = folders.pop()!;
    let offset = 0;
    while (true) {
      const { data: entries, error } = await storage.list(folder, { limit: 100, offset });
      if (error) {
        console.error(`Could not list designer uploads in ${folder}:`, error);
        return jsonResponse(500, { error: "Could not safely remove the designer's uploaded images." });
      }
      for (const entry of entries) {
        const path = `${folder}/${entry.name}`;
        if (entry.id === null) folders.push(path);
        else paths.push(path);
      }
      if (entries.length < 100) break;
      offset += entries.length;
    }
  }

  for (let index = 0; index < paths.length; index += 100) {
    const { error } = await storage.remove(paths.slice(index, index + 100));
    if (error) {
      console.error('Could not remove designer uploads:', error);
      return jsonResponse(500, { error: "Could not safely remove the designer's uploaded images. The account was not deleted." });
    }
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(body.designerId);
  if (deleteError) {
    console.error('Could not delete designer Auth account:', deleteError);
    return jsonResponse(500, { error: 'Uploaded images were removed, but the account could not be deleted. Please retry.' });
  }

  return jsonResponse(200, { success: true });
});
