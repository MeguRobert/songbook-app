// Account administration, behind a server-side rank check.
//
// THE ONLY PLACE IN THIS PROJECT THAT HOLDS THE SERVICE-ROLE KEY. That key
// bypasses row-level security entirely, so the only thing standing between a
// caller and every account in the project is the is_administrator() check below.
// It runs as the CALLER, using their own JWT, and it runs BEFORE any privileged
// client is constructed. Never reorder those two steps, and never move the
// privileged client above the check "to save a round trip".
//
// Why an Edge Function exists at all: listing auth.users, inviting an account and
// deleting one are impossible with the publishable key by design. Email addresses
// live in auth.users and are exposed nowhere else in the app, so this function is
// also the only place one is visible -- which is the correct amount of exposure.
//
// The client's own answer to "am I an administrator" (isAdminProvider in the
// Flutter app) is for hiding buttons. It is never an authorisation. Forcing it
// true gets a 403 from here.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

type Action =
  | { action: 'list' }
  | { action: 'invite'; email: string; role?: string }
  | { action: 'set_role'; userId: string; role: string }
  | { action: 'delete'; userId: string }

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'unauthenticated' }, 401)

  // -------------------------------------------------------------------------
  // Step 1: who is calling, and may they? As the caller, with the anon key.
  // -------------------------------------------------------------------------
  const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: callerData } = await asCaller.auth.getUser()
  if (!callerData?.user) return json({ error: 'unauthenticated' }, 401)

  const { data: allowed } = await asCaller.rpc('is_administrator')
  if (allowed !== true) return json({ error: 'forbidden' }, 403)

  const callerId = callerData.user.id
  const { data: callerProfile } = await asCaller
    .from('profiles')
    .select('display_name')
    .eq('id', callerId)
    .maybeSingle()

  // Falls back to the email only for the audit log, which is administrator-read
  // and already contains addresses. It is never rendered to a member.
  const callerName = callerProfile?.display_name ?? callerData.user.email ?? null

  // -------------------------------------------------------------------------
  // Step 2: only now, a privileged client.
  // -------------------------------------------------------------------------
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  let body: Action
  try {
    body = await req.json()
  } catch {
    return json({ error: 'bad_request' }, 400)
  }

  const audit = (
    action: string,
    targetUserId: string | null,
    targetEmail: string | null,
    details: Record<string, unknown>,
  ) =>
    admin.from('admin_audit').insert({
      actor_id: callerId,
      actor_name: callerName,
      action,
      target_user_id: targetUserId,
      target_email: targetEmail,
      details,
    })

  // How many administrators remain. Used to refuse removing the last one.
  const administratorCount = async () => {
    const { count } = await admin
      .from('user_roles')
      .select('user_id', { count: 'exact', head: true })
      .eq('role', 'administrator')
    return count ?? 0
  }

  const roleOf = async (userId: string) => {
    const { data } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .maybeSingle()
    return data?.role ?? 'member'
  }

  switch (body.action) {
    // -----------------------------------------------------------------------
    case 'list': {
      const { data: list, error } = await admin.auth.admin.listUsers({
        perPage: 1000,
      })
      if (error) return json({ error: error.message }, 500)

      // Three reads rather than a join: auth.users is not reachable from
      // PostgREST at all, so the account list has to come from the admin API and
      // be stitched to the public tables here.
      const [roles, profiles, songs] = await Promise.all([
        admin.from('user_roles').select('user_id, role'),
        admin.from('profiles').select('id, display_name, guidelines_accepted_at'),
        admin.from('songs').select('owner_id, status').eq('source', 'user'),
      ])

      const roleBy = new Map((roles.data ?? []).map((r) => [r.user_id, r.role]))
      const profileBy = new Map((profiles.data ?? []).map((p) => [p.id, p]))

      const tally = new Map<string, Record<string, number>>()
      for (const song of songs.data ?? []) {
        // Orphaned songs have no owner to credit the count to. They are still in
        // the catalogue; they just belong to nobody's tally any more.
        if (!song.owner_id) continue
        const t = tally.get(song.owner_id) ??
          { approved: 0, pending: 0, rejected: 0, draft: 0 }
        if (song.status in t) t[song.status]++
        tally.set(song.owner_id, t)
      }

      return json({
        users: list.users.map((u) => ({
          id: u.id,
          email: u.email,
          emailConfirmed: u.email_confirmed_at != null,
          createdAt: u.created_at,
          lastSignInAt: u.last_sign_in_at,
          role: roleBy.get(u.id) ?? 'member',
          displayName: profileBy.get(u.id)?.display_name ?? null,
          guidelinesAcceptedAt:
            profileBy.get(u.id)?.guidelines_accepted_at ?? null,
          songs: tally.get(u.id) ??
            { approved: 0, pending: 0, rejected: 0, draft: 0 },
        })),
      })
    }

    // -----------------------------------------------------------------------
    case 'invite': {
      const { data, error } = await admin.auth.admin.inviteUserByEmail(body.email)
      if (error) return json({ error: error.message }, 400)

      // The provisioning trigger has already given them 'member'; this only runs
      // when the invite is for something higher.
      if (body.role && body.role !== 'member') {
        const { error: roleError } = await admin
          .from('user_roles')
          .upsert({ user_id: data.user.id, role: body.role })
        if (roleError) return json({ error: roleError.message }, 400)
      }

      await audit('user_invited', data.user.id, body.email, {
        role: body.role ?? 'member',
      })
      return json({ ok: true, userId: data.user.id })
    }

    // -----------------------------------------------------------------------
    case 'set_role': {
      // Refusal 1: not yourself. One tap from demoting yourself out of this
      // function and never being able to call it again.
      if (body.userId === callerId) {
        return json({ error: 'cannot_change_own_role' }, 400)
      }

      const previous = await roleOf(body.userId)

      // Refusal 2: not the last administrator.
      //
      // UNREACHABLE WHILE REFUSAL 1 STANDS, and kept deliberately. For the
      // target to be an administrator while the count is 1, the target must be
      // the only administrator -- but the caller is an administrator too, which
      // makes at least two. So refusal 1 already prevents total lockout.
      //
      // It stays because it is the backstop for the day somebody relaxes refusal
      // 1 to allow "demote myself once I have appointed a successor". That change
      // is a two-line edit in this file and would otherwise silently reintroduce
      // the lockout. Cheap, and the comment is what stops it being deleted as
      // dead code by someone who checked only the current call graph.
      if (previous === 'administrator' && body.role !== 'administrator') {
        if ((await administratorCount()) <= 1) {
          return json({ error: 'last_administrator' }, 400)
        }
      }

      const { error } = await admin
        .from('user_roles')
        .upsert({ user_id: body.userId, role: body.role })
      if (error) return json({ error: error.message }, 400)

      await audit('role_changed', body.userId, null, {
        from: previous,
        to: body.role,
      })
      return json({ ok: true })
    }

    // -----------------------------------------------------------------------
    case 'delete': {
      if (body.userId === callerId) {
        return json({ error: 'cannot_delete_self' }, 400)
      }

      const previous = await roleOf(body.userId)
      if (previous === 'administrator' && (await administratorCount()) <= 1) {
        return json({ error: 'last_administrator' }, 400)
      }

      // Audited BEFORE the delete, on purpose: afterwards there is no row left
      // to read the address from, and "who did we remove" is the single most
      // useful thing this log records.
      const { data: target } = await admin.auth.admin.getUserById(body.userId)
      await audit('user_deleted', body.userId, target?.user?.email ?? null, {
        role: previous,
      })

      const { error } = await admin.auth.admin.deleteUser(body.userId)
      if (error) return json({ error: error.message }, 400)

      // Their songs are not gone -- the FK is ON DELETE SET NULL and the
      // approved ones stay in the catalogue under their frozen
      // submitted_by_name. See migration 20260822120300.
      return json({ ok: true })
    }

    default:
      return json({ error: 'unknown_action' }, 400)
  }
})
