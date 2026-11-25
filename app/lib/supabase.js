let clientPromise;
export function hasCloudConfig(){const c=window.MUMAO_CONFIG||{};return /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(c.supabaseUrl||'')&&!String(c.supabaseAnonKey||'').includes('YOUR_')}
export async function getSupabase(){if(!hasCloudConfig())return null;if(!clientPromise)clientPromise=import('https://esm.sh/@supabase/supabase-js@2.86.0').then(({createClient})=>createClient(window.MUMAO_CONFIG.supabaseUrl,window.MUMAO_CONFIG.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true},realtime:{params:{eventsPerSecond:10}}}));return clientPromise}
export async function getSession(){const client=await getSupabase();if(!client)return null;const {data,error}=await client.auth.getSession();if(error)throw error;return data.session}
export async function signIn(email,password){const client=await getSupabase();const {data,error}=await client.auth.signInWithPassword({email,password});if(error)throw error;return data}
export async function requestPasswordReset(email){const client=await getSupabase();const {error}=await client.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});if(error)throw error}
export async function signOut(){const client=await getSupabase();const {error}=await client.auth.signOut();if(error)throw error}
