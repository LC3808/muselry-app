# kto-nearby-places (Phase 1A)

Flutter → 이 Edge Function → KTO 위치기반 관광정보(`KorService2/locationBasedList2`)
"함께 가볼 만한 곳" 후보를 서버에서 화이트리스트 필터·정규화해 반환한다.

## 정책
- contentTypeId 화이트리스트 **[12,14,25,28]** (관광지·문화시설·여행코스·레포츠). 음식점(39)·숙박(32)·쇼핑(38) 제외.
  - `_shared/kto.ts`의 `DEFAULT_ALLOWED_CONTENT_TYPES`로 관리. **추천 타입 정책은 서버가 결정하며 요청으로 override 불가.**
- 미지정(전체) 1회 호출(`numOfRows=100`) 후 서버 필터 → contentid 중복제거 → 거리(distanceM) 오름차순 → 상위 `limit`(기본 5).
- **캐시: best-effort in-memory.** 동일 Edge Function isolate가 유지되는 동안 최대 24h 재사용하며, isolate 종료/재생성 시 소멸할 수 있다(persistent 캐시 아님). 이번 Phase에서는 DB 캐시 테이블을 추가하지 않는다.
- 서비스키는 Secret(`KTO_SERVICE_KEY`, **Decoding 키**). 앱/응답/로그에 반환하지 않음.

## 오류/장애 정책
- **client 요청 오류 → HTTP 4xx**: `invalid_json`(400), `lat_lng_required`(400), `invalid_coordinates`(400), `invalid_radius`(400), `method_not_allowed`(405).
- **KTO upstream 장애(timeout/HTTP/resultCode/parsing) → HTTP 200 + `items:[]` + `error:"kto_fetch_failed"`**: 정상 client 요청에 대해 upstream 장애가 Museum 상세화면 전체 장애로 전파되지 않도록 격리.
- 서비스키 미설정 → HTTP 200 + `error:"service_key_not_set"` (장애격리 유지) + 서버 로그 `console.error`로 즉시 식별.

## 요청/응답 계약
Request (POST body): 필수 `lat`,`lng` / 선택 `radius`(기본 5000, 양수만), `limit`(기본 5, 1~20 clamp).
```json
{ "lat": 37.523989, "lng": 126.980357, "radius": 5000, "limit": 5 }
```
> `contentTypeIds`는 공개 계약에 없음(서버 정책 고정).

Response:
```json
{ "source": "kto_location", "fetchedAt": "<ISO>", "cached": false,
  "items": [{ "externalId":"...", "contentTypeId":14, "category":"문화시설",
    "title":"...", "address":"...", "lat":0, "lng":0, "distanceM":0,
    "imageUrl":"...", "thumbnailUrl":"...", "copyrightCode":"Type3" }] }
```

## 배포 (운영자)
```bash
supabase secrets set KTO_SERVICE_KEY="<디코딩_서비스키>"   # .env의 TOURAPI_KEY 값(Decoding)
supabase functions deploy kto-nearby-places
```
> 인증(`verify_jwt`) 정책은 배포 후 실제 프로젝트 설정으로 확인한다(Phase 1C 연결 전 로그인/비로그인 노출 정책 결정 필요). 이번 단계에서 `--no-verify-jwt`를 임의 적용하지 않는다.

## 로컬 테스트 (배포 전)
```bash
supabase functions serve kto-nearby-places --env-file supabase/.env.local   # KTO_SERVICE_KEY 포함
curl -s -X POST http://localhost:54321/functions/v1/kto-nearby-places \
  -H "Content-Type: application/json" -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -d '{"lat":37.523989,"lng":126.980357,"radius":5000,"limit":5}'
```
기대: 아모레퍼시픽미술관·용산가족공원 등이 거리순으로, 음식점 없이 반환.

## Flutter 호출 (Phase 1C, 미착수)
```dart
final res = await Supabase.instance.client.functions.invoke(
  'kto-nearby-places',
  body: {'lat': museum.latitude, 'lng': museum.longitude, 'radius': 5000, 'limit': 5},
);
// res.data['items'] → 카드 렌더 (실패/빈 목록이면 섹션 숨김)
```
