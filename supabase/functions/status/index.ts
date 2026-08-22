// 점빵이 베타 현황 API — 암호를 아는 사람만 조회. 서비스롤로 전체 데이터를 읽어 요약해 돌려준다.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-status-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const key = req.headers.get("x-status-key") || "";
  const want = Deno.env.get("STATUS_KEY") || "";
  // 타이밍 노출을 줄이기 위해 항상 짧게 지연
  await new Promise((r) => setTimeout(r, 400));
  if (!want || key !== want) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { ...cors, "content-type": "application/json" } });
  }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const [profiles, spots, places, reviews, picks, subs, reqs] = await Promise.all([
    sb.from("profiles").select("id,nickname,created_at").order("created_at"),
    sb.from("spots").select("user_id,name,days,lat,lng,radius_m,radius_label,meal_times").order("created_at"),
    sb.from("places").select("name,lat,lng,region,active,created_at"),
    sb.from("reviews").select("user_id,place_id,rate,comment,visited_on,updated_at"),
    sb.from("picks").select("user_id,pick_date,slot,place_id"),
    sb.from("push_subs").select("user_id"),
    sb.from("explore_requests").select("user_id,note,slot,lat,lng,radius_m,created_at").order("created_at"),
  ]);
  return new Response(JSON.stringify({
    now: new Date().toISOString(),
    profiles: profiles.data ?? [], spots: spots.data ?? [], places: places.data ?? [],
    reviews: reviews.data ?? [], picks: picks.data ?? [], subs: subs.data ?? [], reqs: reqs.data ?? [],
  }), { headers: { ...cors, "content-type": "application/json" } });
});
