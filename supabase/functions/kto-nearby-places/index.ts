// Phase 1A — kto-nearby-places
// Flutter → (이 Edge Function) → KTO 위치기반 관광정보(KorService2/locationBasedList2)
//
// 정책:
//   - 미지정(전체) 1회 호출(numOfRows=100) 후 서버에서 화이트리스트(12,14,25,28) 필터
//     → 음식점(39)/숙박(32)/쇼핑(38) 배제. 추천 타입 정책은 서버가 결정(요청 override 불가).
//   - contentid 중복 제거 → 거리(distanceM) 오름차순 → 상위 limit(기본 5) 반환.
//   - best-effort in-memory 캐시: 동일 isolate 유지 중 최대 24h 재사용.
//     isolate 종료/재생성 시 소멸 가능(persistent 캐시 아님).
//   - 서비스키는 Secret(KTO_SERVICE_KEY, Decoding). 앱/응답/로그에 반환 금지.
//   - KTO upstream 장애 시 HTTP 200 + items:[] + error → 앱은 추천 섹션만 숨김.
//   - 잘못된 client 요청은 400(invalid_json/lat_lng_required/invalid_coordinates/invalid_radius).
//
// 배포:
//   supabase secrets set KTO_SERVICE_KEY="<디코딩키>"
//   supabase functions deploy kto-nearby-places
//
// 호출(Flutter, Phase 1C): supabase.functions.invoke('kto-nearby-places',
//   body: { lat, lng, radius?, limit? })   // contentTypeIds는 계약에 없음

import { jsonResponse, corsHeaders } from "../_shared/cors.ts";
import {
  buildPlaces,
  cacheKey,
  DEFAULT_ALLOWED_CONTENT_TYPES,
  fetchNearbyRaw,
  NearbyPlace,
  validateRequest,
} from "../_shared/kto.ts";

const TTL_MS = 24 * 60 * 60 * 1000; // best-effort, isolate 수명 한정
const FETCH_ROWS = 100; // 수정 A: 근거리 음식점 비중이 높아 필터 후 후보 확보용 상향

interface CacheEntry {
  ts: number;
  items: NearbyPlace[]; // limit 적용 전 전체 목록(다양한 limit 재사용)
}
const cache = new Map<string, CacheEntry>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  // 입력 파싱
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  // 입력 검증 (좌표/좌표범위/radius) — 순수 함수
  const v = validateRequest(body);
  if (!v.ok) {
    return jsonResponse({ error: v.error }, v.status);
  }
  const { lat, lng, radius, limit } = v.value;

  // 추천 타입 정책은 서버가 결정(요청 override 불가, 수정 D)
  const allowed = DEFAULT_ALLOWED_CONTENT_TYPES;

  const now = Date.now();
  const key = cacheKey(lat, lng, radius, allowed);

  // best-effort 캐시 히트
  const hit = cache.get(key);
  if (hit && now - hit.ts < TTL_MS) {
    return jsonResponse({
      source: "kto_location",
      fetchedAt: new Date(hit.ts).toISOString(),
      cached: true,
      items: hit.items.slice(0, limit),
    });
  }

  const serviceKey = Deno.env.get("KTO_SERVICE_KEY") ?? "";
  if (!serviceKey) {
    // configuration error. 장애격리 정책상 200 유지하되 운영 로그로 즉시 식별(수정 9).
    console.error("[kto-nearby-places] KTO_SERVICE_KEY is not set");
    return jsonResponse({
      source: "kto_location",
      fetchedAt: new Date(now).toISOString(),
      cached: false,
      items: [],
      error: "service_key_not_set",
    });
  }

  try {
    const raw = await fetchNearbyRaw({
      serviceKey,
      lat,
      lng,
      radius,
      numOfRows: FETCH_ROWS,
    });

    const items = buildPlaces(raw, allowed);
    cache.set(key, { ts: now, items });

    return jsonResponse({
      source: "kto_location",
      fetchedAt: new Date(now).toISOString(),
      cached: false,
      items: items.slice(0, limit),
    });
  } catch (e) {
    // 장애 격리: KTO 실패해도 200 + 빈 목록 → 앱은 추천 섹션만 숨김
    console.error("[kto-nearby-places] kto_fetch_failed:", String(e));
    return jsonResponse({
      source: "kto_location",
      fetchedAt: new Date(now).toISOString(),
      cached: false,
      items: [],
      error: "kto_fetch_failed",
    });
  }
});
