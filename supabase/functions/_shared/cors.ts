// 공통 CORS 헤더 (Supabase Edge Functions)
// Flutter(모바일)에서는 CORS가 필수는 아니나, 웹/로컬 테스트 및 프리플라이트 대응용.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
