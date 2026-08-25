// The app is served from GitHub Pages and the functions from supabase.co, so
// every browser call here is cross-origin and needs a preflight answer.
//
// `*` for the origin is deliberate and safe for this function: it holds no
// cookies and no ambient credentials, and authorises solely on the bearer token
// in the Authorization header. A permissive origin therefore grants a hostile
// page nothing it could not already do with curl -- it cannot obtain a token by
// making the browser send one it does not have.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
