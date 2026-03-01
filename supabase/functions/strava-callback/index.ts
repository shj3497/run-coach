import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

/**
 * Strava OAuth Callback → App Deep Link Redirect
 *
 * Strava가 authorization code를 이 Edge Function으로 보내면,
 * 앱의 커스텀 URL 스킴(runcoach://)으로 리다이렉트합니다.
 *
 * Flow:
 * 1. 앱 → Strava 인증 페이지 (redirect_uri = 이 Edge Function URL)
 * 2. 사용자 승인 → Strava → 이 Edge Function (?code=xxx&scope=...)
 * 3. 이 Edge Function → runcoach://strava-callback?code=xxx (302 redirect)
 * 4. iOS가 딥링크를 받아 앱으로 전달
 */
serve((req: Request) => {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");
  const scope = url.searchParams.get("scope");

  // Strava가 에러를 반환한 경우 (사용자가 거부 등)
  if (error) {
    const deepLink = `runcoach://strava-callback?error=${encodeURIComponent(error)}`;
    return new Response(null, {
      status: 302,
      headers: { Location: deepLink },
    });
  }

  // code가 없는 비정상 요청
  if (!code) {
    return new Response("Missing authorization code", { status: 400 });
  }

  // 앱 딥링크로 리다이렉트
  let deepLink = `runcoach://strava-callback?code=${encodeURIComponent(code)}`;
  if (scope) {
    deepLink += `&scope=${encodeURIComponent(scope)}`;
  }

  return new Response(null, {
    status: 302,
    headers: { Location: deepLink },
  });
});
