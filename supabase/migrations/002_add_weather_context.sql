-- 날씨 보정 이력 저장용 컬럼 추가
-- workout_logs에 날씨 컨텍스트 (기온, 습도, 풍속, 보정 비율, 원래/보정 페이스)를 저장
ALTER TABLE workout_logs ADD COLUMN weather_context jsonb;
