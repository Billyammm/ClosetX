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

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character] ?? character);
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

  let body: { designerId?: unknown; status?: unknown; reason?: unknown };
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }
  if (typeof body.designerId !== 'string'
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.designerId)) {
    return jsonResponse(400, { error: 'A valid designer account ID is required.' });
  }
  if (body.status !== 'approved' && body.status !== 'rejected') {
    return jsonResponse(400, { error: 'The application decision must be approved or rejected.' });
  }
  const reason = typeof body.reason === 'string' ? body.reason.trim() : '';
  if (body.status === 'rejected' && !reason) {
    return jsonResponse(400, { error: 'A reason is required when rejecting an application.' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const emailFrom = Deno.env.get('EMAIL_FROM');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Required Supabase Edge Function environment variables are missing.');
    return jsonResponse(500, { error: 'Application review is not configured on the server.' });
  }
  if (!resendApiKey || !emailFrom) {
    console.error('Resend email environment variables are missing.');
    return jsonResponse(500, {
      error: 'Email notifications are not configured. Set RESEND_API_KEY and EMAIL_FROM in Supabase secrets.',
    });
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
    return jsonResponse(403, { error: 'Only a ClosetX administrator can review applications.' });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const reviewedAt = new Date().toISOString();
  const { data: profile, error: reviewError } = await adminClient
    .from('profiles')
    .update({
      designer_status: body.status,
      designer_rejection_reason: body.status === 'rejected' ? reason : null,
      designer_reviewed_at: reviewedAt,
    })
    .eq('id', body.designerId)
    .eq('role', 'designer')
    .eq('designer_status', 'pending')
    .select('id, email, full_name')
    .maybeSingle();
  if (reviewError) {
    console.error('Could not save designer application decision:', reviewError);
    return jsonResponse(500, { error: 'Could not save the application decision.' });
  }
  if (!profile) {
    return jsonResponse(409, { error: 'This application has already been reviewed or does not exist.' });
  }

  const recipient = typeof profile.email === 'string' ? profile.email.trim() : '';
  if (!recipient) {
    console.error('Designer application has no registered email address.');
    return jsonResponse(200, {
      success: true,
      emailSent: false,
      warning: 'The application decision was saved, but no email address is available for this account.',
    });
  }

  const name = typeof profile.full_name === 'string' && profile.full_name.trim()
    ? profile.full_name.trim()
    : 'Designer';
  const approved = body.status === 'approved';
  const title = approved ? 'Your designer application was accepted' : 'Your designer application was declined';
  const message = approved
    ? 'Your ClosetX designer account is now approved. Sign in to create your brand and upload designs.'
    : `Your ClosetX designer application was not approved.${reason ? ` Review reason: ${reason}` : ''}`;
  const safeName = escapeHtml(name);
  const safeMessage = escapeHtml(message);
  const emailPayload = {
    from: emailFrom,
    to: [recipient],
    subject: title,
    text: `Hi ${name},\n\n${message}\n\nThe ClosetX team`,
    html: `<div style="font-family:Arial,sans-serif;line-height:1.6;color:#172033"><h1 style="font-size:22px">${escapeHtml(title)}</h1><p>Hi ${safeName},</p><p>${safeMessage}</p><p>The ClosetX team</p></div>`,
  };

  try {
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailPayload),
    });
    if (!emailResponse.ok) {
      console.error('Resend rejected the designer application email:', emailResponse.status);
      return jsonResponse(200, {
        success: true,
        emailSent: false,
        warning: 'The application decision was saved, but the email notification could not be sent. Check the Resend sender configuration.',
      });
    }
  } catch (error) {
    console.error('Could not reach Resend for the designer application email:', error);
    return jsonResponse(200, {
      success: true,
      emailSent: false,
      warning: 'The application decision was saved, but the email service could not be reached.',
    });
  }

  return jsonResponse(200, { success: true, emailSent: true });
});
