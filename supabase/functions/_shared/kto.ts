// 한국관광공사(KTO) 국문 관광정보 서비스_GW — 위치기반 조회 유틸
// 공식 명세(2026-08-10 라이브 검증):
//   Base: https://apis.data.go.kr/B551011/KorService2
//   Op:   /locationBasedList2  (mapX=경도, mapY=위도, radius=m, arrange=E 거리순)
//   응답: contentid, contenttypeid, title, addr1/2, mapx, mapy, dist(m),
//         firstimage, firstimage2, cpyrhtDivCd, lclsSystm1~3, lDong* 등
//
// ⚠ 서비스키는 Decoding 키(원문)를 Secret에 저장 → URLSearchParams가 1회만 인코딩.
//   이미 인코딩된 키(%2B 등)를 넣으면 이중 인코딩으로 실패하므로 Decoding 키 사용.

export const KORSERVICE2_LOCATION_URL =
  "https://apis.data.go.kr/B551011/KorService2/locationBasedList2";

// contentTypeId → 한글 라벨 (국문 콘텐츠타입 코드표)
export const CONTENT_TYPE_LABELS: Record<number, string> = {
  12: "관광지",
  14: "문화시설",
  15: "축제공연행사",
  25: "여행코스",
  28: "레포츠",
  32: "숙박",
  38: "쇼핑",
  39: "음식점",
};

// "함께 가볼 만한 곳" Production 화이트리스트 (운영자 결정 2026-08-10):
//   관광지 + 문화시설 + 여행코스 + 레포츠 (음식점 39 / 숙박 32 / 쇼핑 38 제외)
// ※ 서버 정책. 공개 요청 계약으로 override 불가(수정 D).
export const DEFAULT_ALLOWED_CONTENT_TYPES = [12, 14, 25, 28];

// 입력 기본값/상한
export const DEFAULT_RADIUS = 5000; // 5km
export const DEFAULT_LIMIT = 5;
export const MAX_LIMIT = 20;
// KTO locationBasedList2 공식 최대 반경 = 20km (2026 관광데이터 활용 공모전 OpenAPI 설명회 자료 p.5 "최대 20Km").
export const MAX_RADIUS = 20000;

export interface NearbyPlace {
  externalId: string;
  contentTypeId: number;
  category: string;
  title: string;
  address: string;
  lat: number;
  lng: number;
  distanceM: number;
  imageUrl: string;
  thumbnailUrl: string;
  copyrightCode: string;
}

export interface KtoRawItem {
  contentid?: string;
  contenttypeid?: string;
  title?: string;
  addr1?: string;
  addr2?: string;
  mapx?: string;
  mapy?: string;
  dist?: string;
  firstimage?: string;
  firstimage2?: string;
  cpyrhtDivCd?: string;
}

// ── 입력 검증 (순수 함수, 테스트 대상) ─────────────────────────────────────────
export interface ValidatedRequest {
  lat: number;
  lng: number;
  radius: number;
  limit: number;
}
export type ValidateResult =
  | { ok: true; value: ValidatedRequest }
  | { ok: false; status: number; error: string };

export function validateRequest(body: unknown): ValidateResult {
  const b = (body ?? {}) as Record<string, unknown>;

  const lat = Number(b.lat);
  const lng = Number(b.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return { ok: false, status: 400, error: "lat_lng_required" };
  }
  // 좌표 범위 검증 (수정 B): 잘못된 좌표가 KTO upstream으로 전달되지 않도록
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return { ok: false, status: 400, error: "invalid_coordinates" };
  }

  // radius (수정 C): 제공 시 유한 & 양수만 허용. 음수/0/비정상 → 400.
  let radius = DEFAULT_RADIUS;
  if (b.radius !== undefined && b.radius !== null) {
    const r = Number(b.radius);
    if (!Number.isFinite(r) || r <= 0) {
      return { ok: false, status: 400, error: "invalid_radius" };
    }
    radius = Math.min(r, MAX_RADIUS); // 20km 상한 clamp (수정 C 후속)
  }

  // limit: 기본 5, 1~20 clamp
  let limit = DEFAULT_LIMIT;
  if (b.limit !== undefined && b.limit !== null) {
    const l = Number(b.limit);
    if (Number.isFinite(l)) limit = Math.max(1, Math.min(MAX_LIMIT, l));
  }

  return { ok: true, value: { lat, lng, radius, limit } };
}

// ── KTO 호출 ──────────────────────────────────────────────────────────────────
/** KTO 위치기반 호출 → raw item 배열. 실패 시 throw. */
export async function fetchNearbyRaw(opts: {
  serviceKey: string;
  lat: number;
  lng: number;
  radius: number;
  numOfRows: number;
  timeoutMs?: number;
}): Promise<KtoRawItem[]> {
  const { serviceKey, lat, lng, radius, numOfRows } = opts;
  const params = new URLSearchParams({
    serviceKey, // URLSearchParams가 1회 인코딩 (Decoding 키 전제)
    MobileOS: "ETC",
    MobileApp: "Muselry",
    mapX: String(lng), // x = 경도
    mapY: String(lat), // y = 위도
    radius: String(radius),
    numOfRows: String(numOfRows),
    pageNo: "1",
    arrange: "E", // 거리순 (서버에서 distanceM 재정렬도 수행)
    _type: "json",
  });
  const url = `${KORSERVICE2_LOCATION_URL}?${params.toString()}`;

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), opts.timeoutMs ?? 8000);
  let res: Response;
  try {
    res = await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(t);
  }
  if (!res.ok) throw new Error(`KTO HTTP ${res.status}`);

  const text = await res.text();
  // 오류 시 _type=json이어도 XML로 오는 경우가 있어 방어적으로 파싱
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`KTO non-JSON response: ${text.slice(0, 200)}`);
  }
  const d = data as any;
  const resultCode = d?.response?.header?.resultCode;
  if (resultCode !== "0000") {
    const msg = d?.response?.header?.resultMsg ?? "unknown";
    throw new Error(`KTO resultCode=${resultCode} (${msg})`);
  }
  const items = d?.response?.body?.items?.item;
  if (!items) return [];
  return Array.isArray(items) ? items : [items];
}

// ── 정규화 (NaN 방어, 수정 E) ─────────────────────────────────────────────────
/**
 * raw item → NearbyPlace. 원본 무가공, 파생값(category/distanceM/address)만 계산.
 * contenttypeid/mapx/mapy/dist가 유효 숫자가 아니거나 contentid 없으면 null(후보 제외).
 */
export function normalize(item: KtoRawItem): NearbyPlace | null {
  const externalId = (item.contentid ?? "").trim();
  const contentTypeId = Number(item.contenttypeid);
  const lat = Number(item.mapy);
  const lng = Number(item.mapx);
  const distanceM = Number(item.dist);

  if (
    !externalId ||
    !Number.isFinite(contentTypeId) ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    !Number.isFinite(distanceM)
  ) {
    return null;
  }

  const address = [item.addr1, item.addr2]
    .map((s) => (s ?? "").trim())
    .filter(Boolean)
    .join(" ");

  return {
    externalId,
    contentTypeId,
    category: CONTENT_TYPE_LABELS[contentTypeId] ?? "기타",
    title: (item.title ?? "").trim(),
    address,
    lat,
    lng,
    distanceM: Math.round(distanceM),
    imageUrl: item.firstimage ?? "",
    thumbnailUrl: item.firstimage2 ?? "",
    copyrightCode: item.cpyrhtDivCd ?? "",
  };
}

/**
 * raw → 정규화 → 화이트리스트 필터 → contentid 중복제거 → 거리 오름차순.
 * limit slice는 호출부에서 수행(전체 결과를 캐시해 다양한 limit 재사용).
 */
export function buildPlaces(
  raw: KtoRawItem[],
  allowed: number[],
): NearbyPlace[] {
  const allowedSet = new Set(allowed);
  const seen = new Set<string>();
  return raw
    .map(normalize)
    .filter((p): p is NearbyPlace => p !== null)
    .filter((p) => allowedSet.has(p.contentTypeId))
    .filter((p) => (seen.has(p.externalId) ? false : (seen.add(p.externalId), true)))
    .sort((a, b) => a.distanceM - b.distanceM);
}

/** 캐시 키: 좌표 3자리 + radius + 화이트리스트 버전(정책 변경 시 캐시 충돌 방지) */
export function cacheKey(
  lat: number,
  lng: number,
  radius: number,
  allowed: number[],
): string {
  return `${lat.toFixed(3)}|${lng.toFixed(3)}|${radius}|${allowed.join(",")}`;
}
