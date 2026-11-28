import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.86.0';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return json({error:'method_not_allowed'},405);
  try{
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const auth=req.headers.get('Authorization');if(!auth)return json({error:'authentication_required'},401);
    const caller=createClient(url,anon,{global:{headers:{Authorization:auth}}});
    const {data:{user},error:userError}=await caller.auth.getUser();if(userError||!user)return json({error:'invalid_session'},401);
    const {organizationId,email,role,redirectTo}=await req.json();
    if(!organizationId||!email||!['manager','staff'].includes(role))return json({error:'invalid_input'},400);
    const admin=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}});
    const {data:membership}=await admin.from('organization_members').select('role,status').eq('organization_id',organizationId).eq('user_id',user.id).eq('status','active').maybeSingle();
    if(membership?.role!=='owner')return json({error:'owner_permission_required'},403);
    const {data:invite,error:inviteError}=await admin.auth.admin.inviteUserByEmail(String(email).trim().toLowerCase(),{redirectTo,data:{display_name:String(email).split('@')[0]}});
    if(inviteError||!invite.user)return json({error:'invite_failed',message:inviteError?.message},400);
    const {error:memberError}=await admin.from('organization_members').upsert({organization_id:organizationId,user_id:invite.user.id,role,status:'active',invited_by:user.id,joined_at:new Date().toISOString()},{onConflict:'organization_id,user_id'});
    if(memberError)return json({error:'membership_failed',message:memberError.message},400);
    return json({ok:true,userId:invite.user.id});
  }catch(error){return json({error:'unexpected_error',message:error instanceof Error?error.message:'unknown'},500)}
});
