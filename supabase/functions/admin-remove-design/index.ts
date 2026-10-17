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

  let body: { designId?: unknown };
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }
  if (typeof body.designId !== 'string'
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.designId)) {
    return jsonResponse(400, { error: 'A valid design ID is required.' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Required Supabase Edge Function environment variables are missing.');
    return jsonResponse(500, { error: 'Design removal is not configured on the server.' });
  }

  const token = authorization.slice('Bearer '.length);
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse(401, { error: 'Your session is invalid or expired. Sign in again.' });
  }
  if (user.app_metadata?.closetx_admin !== true) {
    return jsonResponse(403, { error: 'Only a ClosetX administrator can remove designs.' });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: design, error: lookupError } = await adminClient
    .from('designs')
    .select('id, front_image_path, back_image_path, thumbnail_path')
    .eq('id', body.designId)
    .maybeSingle();
  if (lookupError) {
    console.error('Could not look up design:', lookupError);
    return jsonResponse(500, { error: 'Could not verify the design.' });
  }
  if (!design) {
    return jsonResponse(404, { error: 'Design not found.' });
  }

  const { data: deletedDesign, error: deleteError } = await adminClient
    .from('designs')
    .delete()
    .eq('id', body.designId)
    .select('id')
    .maybeSingle();
  if (deleteError) {
    console.error('Could not delete design:', deleteError);
    return jsonResponse(500, { error: 'Could not remove the design.' });
  }
  if (!deletedDesign) {
    return jsonResponse(404, { error: 'Design was already removed.' });
  }

  const imagePaths = [...new Set([
    design.front_image_path,
    design.back_image_path,
    design.thumbnail_path,
  ].filter((path): path is string => typeof path === 'string' && path.length > 0))];
  if (!imagePaths.length) return jsonResponse(200, { success: true });

  const { error: storageError } = await adminClient.storage
    .from('design-images')
    .remove(imagePaths);
  if (storageError) {
    console.error('Design was removed but uploaded images could not be cleaned up:', storageError);
    return jsonResponse(200, {
      success: true,
      warning: 'One or more uploaded images could not be deleted.',
    });
  }

  return jsonResponse(200, { success: true });
});
