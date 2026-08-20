// 뭐먹정 — 공개 시각 푸시 발송 (매분 pg_cron이 호출)
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push";

const SLOT_LABEL: Record<string, string> = { breakfast: "아침", lunch: "점심", dinner: "저녁", latenight: "야식" };
const HOLIDAYS = new Set([
  "2026-01-01","2026-02-16","2026-02-17","2026-02-18","2026-03-01","2026-03-02",
  "2026-05-05","2026-05-24","2026-05-25","2026-06-06","2026-08-15","2026-08-17",
  "2026-09-24","2026-09-25","2026-09-26","2026-09-28","2026-10-03","2026-10-05",
  "2026-10-09","2026-12-25",
  "2027-01-01","2027-02-06","2027-02-07","2027-02-08","2027-02-09","2027-03-01",
  "2027-05-05","2027-05-13","2027-06-06","2027-08-15","2027-08-16",
  "2027-09-14","2027-09-15","2027-09-16","2027-10-03","2027-10-04",
  "2027-10-09","2027-10-11","2027-12-25","2027-12-27",
]);

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== Deno.env.get("PUSH_TICK_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  webpush.setVapidDetails("mailto:toommp3@gmail.com", Deno.env.get("VAPID_PUBLIC")!, Deno.env.get("VAPID_PRIVATE")!);

  // KST 현재 시각 (직전 1분까지 포함해 크론 지연 보정, push_log로 중복 방지)
  const kst = new Date(Date.now() + 9 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  const today = `${kst.getUTCFullYear()}-${pad(kst.getUTCMonth() + 1)}-${pad(kst.getUTCDate())}`;
  const nowMin = kst.getUTCHours() * 60 + kst.getUTCMinutes();
  const hhmm = (m: number) => `${pad(Math.floor(m / 60))}:${pad(m % 60)}`;
  const windowTimes = [hhmm(nowMin), hhmm((nowMin + 1439) % 1440)];
  const wd = kst.getUTCDay();
  const weekendLike = wd === 0 || wd === 6 || HOLIDAYS.has(today);

  const { data: spots } = await sb.from("spots").select("user_id,days,meal_times,lat,lng,radius_m,created_at").order("created_at");
  if (!spots) return new Response("no spots");
  const { data: places } = await sb.from("places").select("lat,lng,slots").eq("active", true);
  const distM = (a1: number, o1: number, a2: number, o2: number) => {
    const R = 6371000, r = (x: number) => x * Math.PI / 180;
    const h = Math.sin(r(a2 - a1) / 2) ** 2 + Math.cos(r(a1)) * Math.cos(r(a2)) * Math.sin(r(o2 - o1) / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(h));
  };

  // 사용자별 활성 장소 (평일/주말·공휴일 2슬롯 모델)
  const byUser = new Map<string, any[]>();
  for (const s of spots) {
    if (!byUser.has(s.user_id)) byUser.set(s.user_id, []);
    byUser.get(s.user_id)!.push(s);
  }
  const due: { user_id: string; slot: string; time: string }[] = [];
  for (const [uid, list] of byUser) {
    const active =
      (list.length > 1 ? list.find((s) => s.days === (weekendLike ? "weekend" : "weekday")) : null) ||
      list.find((s) => s.days === "always") || list[0];
    for (const mt of active.meal_times || []) {
      if (!windowTimes.includes(mt.time)) continue;
      // 보여줄 후보가 없는 동네·시간대면 알림을 보내지 않음 (발굴중 화면만 보게 되므로)
      const hasCand = (places || []).some((p) =>
        (p.slots || []).includes(mt.slot) && distM(active.lat, active.lng, p.lat, p.lng) <= active.radius_m);
      if (!hasCand) continue;
      due.push({ user_id: uid, slot: mt.slot, time: mt.time });
    }
  }
  if (!due.length) return new Response("idle");

  let sent = 0;
  for (const d of due) {
    // 중복 발송 방지 — push_log에 처음 기록될 때만 발송
    const { data: ins } = await sb.from("push_log")
      .upsert({ user_id: d.user_id, pick_date: today, slot: d.slot, t: d.time }, { onConflict: "user_id,pick_date,slot,t", ignoreDuplicates: true })
      .select();
    if (!ins || !ins.length) continue;
    const { data: subs } = await sb.from("push_subs").select("*").eq("user_id", d.user_id);
    const label = SLOT_LABEL[d.slot] || "식사";
    const payload = JSON.stringify({
      title: `🍚 오늘 ${label} 뭐먹정!`,
      body: `${d.time} — 오늘의 한 곳이 공개됐어요. 들어와서 확인해보세요.`,
      url: "https://powerpilferer.github.io/jeombbang-beta/",
    });
    for (const s of subs || []) {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload);
        sent++;
      } catch (e: any) {
        if (e && (e.statusCode === 404 || e.statusCode === 410)) {
          await sb.from("push_subs").delete().eq("endpoint", s.endpoint);   // 만료 구독 정리
        }
      }
    }
  }
  return new Response(`sent ${sent}`);
});
