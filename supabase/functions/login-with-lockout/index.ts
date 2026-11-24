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

function clientIp(request: Request) {
  return request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || request.headers.get('cf-connecting-ip')
    || 'unknown';
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse(405, { error: 'Method not allowed.' });

  let body: { email?: unknown; password?: unknown };
  try { body = await request.json(); } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!email || !password) return jsonResponse(400, { error: 'Invalid email or password' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(500, { error: 'Login is not configured on the server.' });
  }

  const ip = clientIp(request);
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: ipAttempt } = await adminClient
    .from('login_ip_attempts')
    .select('failed_attempts, window_started_at')
    .eq('ip_address', ip)
    .maybeSingle();
  const ipWindowValid = ipAttempt
    && Date.now() - new Date(ipAttempt.window_started_at).getTime() < 15 * 60 * 1000;
  if (ipWindowValid && ipAttempt.failed_attempts >= 20) {
    return jsonResponse(429, { error: 'Too many login attempts. Try again later.' });
  }

  const { data: profile } = await adminClient
    .from('profiles')
    .select('id, is_admin_locked, failed_attempts, lockout_stage, locked_until')
    .eq('email', email)
    .maybeSingle();

  if (profile?.id) {
    const { data: lockState, error: lockError } = await adminClient.rpc(
      'check_login_lockout',
      { p_user_id: profile.id },
    );
    if (lockError) return jsonResponse(500, { error: 'Could not verify account status.' });
    if (lockState?.allowed === false) {
      if (lockState.adminLocked) {
        return jsonResponse(423, {
          error: 'Too many failed attempts. Please contact an administrator for assistance.',
          adminLocked: true,
        });
      }
      return jsonResponse(423, {
        error: `Try again in ${lockState.remainingSeconds} seconds`,
        remainingSeconds: lockState.remainingSeconds,
      });
    }
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await authClient.auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    if (!ipWindowValid) {
      await adminClient.from('login_ip_attempts').upsert({
        ip_address: ip,
        failed_attempts: 1,
        window_started_at: new Date().toISOString(),
      });
    } else {
      await adminClient.from('login_ip_attempts').update({
        failed_attempts: ipAttempt.failed_attempts + 1,
      }).eq('ip_address', ip);
    }
    if (profile?.id) {
      const { data: failure } = await adminClient.rpc('record_login_failure', {
        p_user_id: profile.id,
        p_ip: ip,
      });
      if (failure?.adminLocked) {
        return jsonResponse(423, {
          error: 'Too many failed attempts. Please contact an administrator for assistance.',
          adminLocked: true,
        });
      }
      if (failure?.locked) {
        return jsonResponse(423, {
          error: `Try again in ${failure.remainingSeconds} seconds`,
          remainingSeconds: failure.remainingSeconds,
        });
      }
      if (typeof failure?.attemptsLeft === 'number') {
        return jsonResponse(401, {
          error: 'Invalid email or password',
          attemptsLeft: failure.attemptsLeft,
          nextLockSeconds: failure.nextLockSeconds,
        });
      }
    }
    return jsonResponse(401, { error: 'Invalid email or password' });
  }

  await adminClient.rpc('reset_login_lockout', { p_user_id: data.user.id });
  await adminClient.from('login_ip_attempts').delete().eq('ip_address', ip);
  return jsonResponse(200, {
    accessToken: data.session.access_token,
    refreshToken: data.session.refresh_token,
  });
});
