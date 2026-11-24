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

async function sha256(value: string) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes)).map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse(405, { error: 'Method not allowed.' });

  let body: { action?: unknown; email?: unknown; token?: unknown; password?: unknown; confirmPassword?: unknown };
  try { body = await request.json(); } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, { error: 'Password reset is not configured on the server.' });
  }
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (body.action === 'forgot') {
    const ip = clientIp(request);
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const genericMessage = 'If this account exists, a reset link has been sent';

    const { data: ipRequest } = await adminClient
      .from('password_reset_requests')
      .select('request_count, window_started_at')
      .eq('ip_address', ip)
      .maybeSingle();
    const ipWindowValid = ipRequest
      && Date.now() - new Date(ipRequest.window_started_at).getTime() < 60 * 60 * 1000;
    if (ipWindowValid && ipRequest.request_count >= 3) {
      return jsonResponse(200, { success: true, message: genericMessage });
    }

    if (!ipWindowValid) {
      await adminClient.from('password_reset_requests').upsert({
        ip_address: ip, request_count: 1, window_started_at: new Date().toISOString(),
      });
    } else {
      await adminClient.from('password_reset_requests').update({
        request_count: ipRequest.request_count + 1,
      }).eq('ip_address', ip);
    }

    const { data: profile } = await adminClient
      .from('profiles')
      .select('id, email, full_name, is_admin_locked')
      .eq('email', email)
      .maybeSingle();
    if (!profile) return jsonResponse(200, { success: true, message: genericMessage });
    if (profile.is_admin_locked) {
      return jsonResponse(423, {
        error: 'Your account is locked. Please contact an administrator.',
        adminLocked: true,
      });
    }

    const accountRequests = await adminClient
      .from('password_reset_tokens')
      .select('id, created_at')
      .eq('user_id', profile.id)
      .gte('created_at', new Date(Date.now() - 60 * 60 * 1000).toISOString());
    if ((accountRequests.data?.length ?? 0) >= 3) {
      return jsonResponse(200, { success: true, message: genericMessage });
    }

    await adminClient.from('password_reset_tokens').update({ used_at: new Date().toISOString() })
      .eq('user_id', profile.id).is('used_at', null);

    const { data: link, error: linkError } = await adminClient.auth.admin.generateLink({
      type: 'recovery',
      email: profile.email,
    });
    if (linkError || !link?.properties?.hashed_token) {
      console.error('Could not generate password reset link:', linkError);
      return jsonResponse(200, { success: true, message: genericMessage });
    }
    const rawToken = link.properties.hashed_token;
    const tokenHash = await sha256(rawToken);
    await adminClient.from('password_reset_tokens').insert({
      user_id: profile.id,
      token_hash: tokenHash,
      expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
    });

    const emailjsPrivateKey = Deno.env.get('EMAILJS_PRIVATE_KEY');
    const emailjsPublicKey = Deno.env.get('EMAILJS_PUBLIC_KEY');
    const emailjsServiceId = Deno.env.get('EMAILJS_SERVICE_ID');
    const emailjsResetTemplateId = Deno.env.get('EMAILJS_RESET_TEMPLATE_ID');
    const resetPageUrl = Deno.env.get('PASSWORD_RESET_URL');
    const resetLink = resetPageUrl
      ? `${resetPageUrl}${resetPageUrl.includes('?') ? '&' : '?'}token=${encodeURIComponent(rawToken)}`
      : link.properties.action_link;
    if (!emailjsPrivateKey || !emailjsPublicKey
      || !emailjsServiceId || !emailjsResetTemplateId) {
      console.error(
        'Password reset email is not configured. Set EMAILJS_PRIVATE_KEY, EMAILJS_PUBLIC_KEY, EMAILJS_SERVICE_ID, and EMAILJS_RESET_TEMPLATE_ID.',
      );
    } else {
      try {
        const profileName = typeof profile.full_name === 'string'
          && profile.full_name.trim()
          ? profile.full_name.trim()
          : profile.email.split('@')[0];
        const emailResponse = await fetch(
          'https://api.emailjs.com/api/v1.0/email/send',
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              service_id: emailjsServiceId,
              template_id: emailjsResetTemplateId,
              user_id: emailjsPublicKey,
              accessToken: emailjsPrivateKey,
              template_params: {
                to_email: profile.email,
                to_name: profileName,
                reset_link: resetLink,
                expires_in: '15 minutes',
              },
            }),
          },
        );
        if (!emailResponse.ok) {
          const responseText = await emailResponse.text();
          console.error(
            'EmailJS rejected the password reset email:',
            emailResponse.status,
            responseText,
          );
        }
      } catch (error) {
        console.error('Could not reach EmailJS for the password reset email:', error);
      }
    }
    return jsonResponse(200, { success: true, message: genericMessage });
  }

  if (body.action === 'reset') {
    const token = typeof body.token === 'string' ? body.token : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const confirmPassword = typeof body.confirmPassword === 'string' ? body.confirmPassword : '';
    if (password.length < 6) return jsonResponse(400, { error: 'Use at least 6 characters.' });
    if (password !== confirmPassword) return jsonResponse(400, { error: 'The passwords do not match.' });
    if (!token) return jsonResponse(400, { error: 'This password reset link is invalid or expired.' });

    const tokenHash = await sha256(token);
    const { data: resetToken } = await adminClient
      .from('password_reset_tokens')
      .select('id, user_id, expires_at, used_at')
      .eq('token_hash', tokenHash)
      .maybeSingle();
    if (!resetToken || resetToken.used_at
      || new Date(resetToken.expires_at).getTime() <= Date.now()) {
      return jsonResponse(400, { error: 'This password reset link is invalid or expired.' });
    }

    const { data: profile } = await adminClient
      .from('profiles')
      .select('is_admin_locked')
      .eq('id', resetToken.user_id)
      .maybeSingle();
    if (profile?.is_admin_locked) {
      return jsonResponse(423, {
        error: 'Your account is locked. Please contact an administrator.',
        adminLocked: true,
      });
    }

    const { error: updateError } = await adminClient.auth.admin.updateUserById(
      resetToken.user_id,
      { password },
    );
    if (updateError) return jsonResponse(400, { error: 'Could not update the password.' });

    await adminClient.from('password_reset_tokens')
      .update({ used_at: new Date().toISOString() })
      .eq('id', resetToken.id);
    await adminClient.from('password_reset_tokens')
      .update({ used_at: new Date().toISOString() })
      .eq('user_id', resetToken.user_id)
      .is('used_at', null);
    await adminClient.rpc('reset_login_lockout', { p_user_id: resetToken.user_id });
    await adminClient.auth.admin.signOut(resetToken.user_id, 'global');

    return jsonResponse(200, { success: true });
  }

  return jsonResponse(400, { error: 'Unknown password security action.' });
});
