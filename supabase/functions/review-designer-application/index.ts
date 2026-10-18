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
  if (!supabaseUrl || !anonKey) {
    console.error('Required Supabase Edge Function environment variables are missing.');
    return jsonResponse(500, { error: 'Application review is not configured on the server.' });
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

  const { data: profile, error: reviewError } = await userClient
    .from('profiles')
    .update({
      designer_status: body.status,
      designer_rejection_reason: body.status === 'rejected' ? reason : null,
      designer_reviewed_at: new Date().toISOString(),
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

  const emailJsServiceId = Deno.env.get('EMAILJS_SERVICE_ID');
  const emailJsTemplateId = Deno.env.get('EMAILJS_TEMPLATE_ID');
  const emailJsPublicKey = Deno.env.get('EMAILJS_PUBLIC_KEY');
  const emailJsPrivateKey = Deno.env.get('EMAILJS_PRIVATE_KEY');
  if (!emailJsServiceId || !emailJsTemplateId || !emailJsPublicKey || !emailJsPrivateKey) {
    console.error('EmailJS environment variables are missing.');
    return jsonResponse(200, {
      success: true,
      emailSent: false,
      warning: 'The application decision was saved, but email notifications are not configured. Set EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, EMAILJS_PUBLIC_KEY, and EMAILJS_PRIVATE_KEY in Supabase secrets.',
    });
  }

  const name = typeof profile.full_name === 'string' && profile.full_name.trim()
    ? profile.full_name.trim()
    : 'Designer';
  const approved = body.status === 'approved';
  const title = approved
    ? 'Your designer application was accepted'
    : 'Your designer application was declined';
  const message = approved
    ? 'Your ClosetX designer account is now approved. Sign in to create your brand and upload designs.'
    : `Your ClosetX designer application was not approved.${reason ? ` Review reason: ${reason}` : ''}`;

  try {
    const emailResponse = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        service_id: emailJsServiceId,
        template_id: emailJsTemplateId,
        user_id: emailJsPublicKey,
        accessToken: emailJsPrivateKey,
        template_params: {
          to_email: recipient,
          to_name: name,
          subject: title,
          application_status: approved ? 'approved' : 'declined',
          message,
          rejection_reason: approved ? '' : reason,
        },
      }),
    });
    if (!emailResponse.ok) {
      const errorDetails = await emailResponse.text();
      console.error('EmailJS rejected the designer application email:', emailResponse.status, errorDetails);
      return jsonResponse(200, {
        success: true,
        emailSent: false,
        warning: 'The application decision was saved, but EmailJS could not send the notification. Check the EmailJS service and template configuration.',
      });
    }
  } catch (error) {
    console.error('Could not reach EmailJS for the designer application email:', error);
    return jsonResponse(200, {
      success: true,
      emailSent: false,
      warning: 'The application decision was saved, but the email service could not be reached.',
    });
  }

  return jsonResponse(200, { success: true, emailSent: true });
});
