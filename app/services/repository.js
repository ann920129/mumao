import {getSupabase} from '../lib/supabase.js';
import {tomorrowTaipei,taipeiDate} from '../domain/time.js';

function unwrap(result){if(result.error)throw result.error;return result.data}
export class Repository{
  constructor(organizationId){this.organizationId=organizationId;this.client=null}
  async init(){this.client=await getSupabase();return this}
  async membership(){return unwrap(await this.client.from('organization_members').select('organization_id,role,organizations(name)').eq('organization_id',this.organizationId).eq('status','active').single())}
  async dashboard(){const today=taipeiDate(),tomorrow=tomorrowTaipei();return unwrap(await this.client.rpc('dashboard_summary',{p_organization_id:this.organizationId,p_today:today,p_tomorrow:tomorrow}))}
  async rooms(){return unwrap(await this.client.from('rooms').select('id,name,status,sort_order,room_types(code,name,max_cats),room_allocations!left(id,check_in_at,check_out_at,reservation_id,reservations(status,reservation_cats(cats(name))))').eq('organization_id',this.organizationId).order('sort_order'))}
  async reservations(){return unwrap(await this.client.from('reservations').select('id,reservation_number,status,expected_check_in_at,expected_check_out_at,total_amount,deposit_amount,balance_amount,owners(name,phone),reservation_cats(cats(id,name)),room_allocations(rooms(id,name))').eq('organization_id',this.organizationId).order('expected_check_in_at',{ascending:false}).limit(100))}
  async tasks(){return unwrap(await this.client.from('tasks').select('id,title,task_type,status,due_at,priority,assigned_to,cats(name),rooms(name)').eq('organization_id',this.organizationId).in('status',['pending','in_progress','requires_confirmation']).order('priority',{ascending:false}).order('due_at').limit(150))}
  async ownersAndCats(){return unwrap(await this.client.from('owners').select('id,name,phone,cats(id,name)').eq('organization_id',this.organizationId).order('name'))}
  async roomTypes(){return unwrap(await this.client.from('room_types').select('id,code,name,max_cats').eq('organization_id',this.organizationId).eq('active',true).order('sort_order'))}
  async createReservation(payload){return unwrap(await this.client.rpc('create_reservation',{p_organization_id:this.organizationId,p_owner_id:payload.ownerId,p_cat_ids:payload.catIds,p_room_id:payload.roomId,p_expected_check_in_at:payload.checkInAt,p_expected_check_out_at:payload.checkOutAt,p_price_snapshot:payload.priceSnapshot,p_notes:payload.notes||null,p_idempotency_key:payload.idempotencyKey}))}
  async completeTask(taskId,expectedVersion){return unwrap(await this.client.rpc('complete_task',{p_task_id:taskId,p_expected_version:expectedVersion}))}
  async reconcileNotifications(){return unwrap(await this.client.rpc('reconcile_next_day_notifications',{p_organization_id:this.organizationId}))}
  subscribe(onChange){const channel=this.client.channel(`org:${this.organizationId}:operations`).on('postgres_changes',{event:'*',schema:'public',table:'tasks',filter:`organization_id=eq.${this.organizationId}`},onChange).on('postgres_changes',{event:'*',schema:'public',table:'reservations',filter:`organization_id=eq.${this.organizationId}`},onChange).on('postgres_changes',{event:'*',schema:'public',table:'abnormal_events',filter:`organization_id=eq.${this.organizationId}`},onChange).subscribe();return ()=>this.client.removeChannel(channel)}
}
export async function loadMemberships(){const client=await getSupabase();return unwrap(await client.from('organization_members').select('organization_id,role,status,organizations(name)').eq('status','active'))}
