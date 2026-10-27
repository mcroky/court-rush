# 온라인 1대1 구현·운영 기록

2026-10-27. [확정 설계](19-online-multiplayer-plan.md)의 1대1 구현. 공개 배포 검증은 아래에 별도로 기록한다.

이 문서는 v0.9.8 당시의 검증 이력이다. 현재 외형·육성 능력치·방·승패/Elo 정책은 사용자 후속 확정에 따라 [v0.10.0 구현](24-online-rooms-and-ranking.md)으로 변경됐다.

## 구성

- Godot 4.7.2 Standard / Compatibility 유지. Render Node 24 WSS 게이트웨이가 인증·자동 매칭·재접속을 맡고, 별도 Godot headless worker가 실제 45본 리그로 60Hz 판정한다. 초기 수용량은 경기 1개다.
- `scripts/online/duel_simulation.gd`는 기존 게임 판정·모션을 재사용한다. 슬롯별 입력 어댑터만 추가하며 AI 이동·강제 수비 반응은 실행하지 않는다. 균등 포워드 190cm, 장착 외형만 적용, 성장 보상 없음.
- 서버 상태는 20Hz. 상대와 공은 100ms 보간한다. 자기 선수는 방해받지 않는 일반 달리기에서만 서버 확인 sequence 이후 입력을 재적용한다. 최대 200ms·50cm로 제한하며 슛·보유 페이크·급정지·착지·근접 경합은 서버 자세를 따른다. 전체 행동 롤백이나 과거 시각 블록 보정은 제공하지 않는다.
- 45본 회전·이동은 각 16비트 고정소수로 패킹한다. 뼈 이동 오차 <=0.05mm. 메시/텍스처를 제거해 손 판정을 바꾸는 최적화는 하지 않는다.
- 매칭 준비 → 양쪽 코트 준비 → 3초 카운트다운 → 90초/11점. 동점 연장 최대 60초. 메뉴/탭 전환은 입력만 해제하고 서버 시계는 계속된다. 20초 재접속, 명시적 이탈은 기권, 서버/전체 이탈은 무효.

## Supabase 경계

기존 `court-rush` 함수에 online-ticket 및 제한된 서버 동작만 추가했다. `cr_online_servers/tickets/matches/participants`는 RLS와 브라우저 권한 회수로 직접 접근을 막는다. 서버는 새 전용 키만 보유한다. Supabase 관리자 키, 기존 앱 키, 공유 Auth 설정과 `ttk_*`는 변경하지 않는다.

적용 이력: `20261027013312 court_rush_online_duel`, `20261027013411 court_rush_online_minimum_grants`. 재현용 SQL은 `supabase/online-schema.sql`. 함수 배포 v7. 전용 키는 DB에 SHA-256 해시만 저장하며 저장소·웹 export에 포함하지 않는다.

보안 advisor: 신규 cr_online_*의 RLS 정책 없음 INFO는 서버 전용 차단 의도다. 기존 ttk_save_progress 실행 권한 및 공유 Auth leaked-password 경고는 이번 변경과 무관하며 변경하지 않았다. [Supabase linter](https://supabase.com/docs/guides/database/database-linter).

## 검증

- 실제 Godot 권한 서버: 두 슬롯 이동·슛, 균등 프로필, 페이크가 상대 점프를 강제하지 않음, 중복 득점 방지, 서버 시계 종료, 45본 오차 <0.1mm, 상태 <4KiB, 예측 입력 재적용/확인 입력 제거.
- 실제 화면 어댑터: JSON 슬롯 숫자 변환을 포함한 명령 브리지, 슬롯1 카메라/HUD, 서버 뼈 위치 일치, 클라이언트 시계 미진행, 퇴장 후 로컬 복귀.
- 실제 WSS 및 Godot 통합: 두 계정 슬롯 분리, 다른 슬롯/좌표 주입·재전송 거절, 중복 탭, 예약 중 취소 경쟁, 재접속 동일 슬롯과 sequence 초기화, 기권 양쪽 결과 일치.
- 실제 Supabase API: 익명 참가권/공개 서버 호출 차단, 새 테이블 직접 접근 차단, 테스트 계정 매칭·결과 저장, XP/코인 불변(11개 검사).
- 웹 lifecycle, 기존 블록 반사 회귀 통과. 브라우저는 진행 중 사용자 탭 대신 별도 QA 탭을 사용한다.

15분 실제 시간 반복 실행(Windows): 12경기, 스냅샷 17,942개, 평균 2,768바이트. 누적 틱 과부하 없음. 1초 구간 p95의 95백분위 6.33ms, 가장 느린 구간 p95 12.55ms. Godot static memory 48,597,180→48,599,608바이트(+2.4KiB), Node RSS 54.5MB. 전체 컨테이너 RSS나 Render CPU 측정치로 혼동하지 않는다.

## 운영

`server/.env`와 `.env.render`는 Git 제외. `.env.render`의 전용 키·공개 Supabase URL/key·서버 ID·허용 origin만 Render에 전달한다. Docker 기본 실행과 PORT를 덮어쓰지 않는다. `render.yaml`은 Free/Singapore/수동 배포/readyz 구성이다. 다른 앱과 workspace 무료 시간을 공유하고 자동 깨우기 작업을 추가하지 않는다.

배포 중에는 새 매칭 수락을 닫고 진행 경기를 마친 뒤 수동 배포한다. 강제 재시작은 epoch 변경으로 이전 경기를 무효 처리한다. 비상 차단은 `site/online-config.js`의 enabled=false와 cr_online_servers.enabled=false를 사용한다. 로그에 토큰·참가권·개인별 로그인 식별자를 기록하지 않는다.

3대3은 아직 활성화하지 않는다. 동일 인증/매칭/방 계약을 재사용하되 6인 팀 배정·패스/가로채기·팀 카메라·경합·성능 검증을 별도 구현한다. Android/Play 빌드·실기기 검증도 별도다.

## 공개 배포 상태

v0.9.8 공개 확인 완료: https://mcroky.github.io/court-rush/ . 서버 https://court-rush-online.onrender.com, Render service srv-dbg0e56k1f9s73av8rig, Singapore / Free / 수동 배포. 서버 커밋 4dec958, 웹 공개 c33a8dd, Pages 작업 40438063368 성공. 유료 서비스·외부 깨우기 작업은 추가하지 않았다.

최종 Render 실전 자동 검사 13개 통과: 실제 정규 90초+연장 60초를 실제 시간 151.502초에 완료했고 양쪽 무승부·저장 결과·XP/코인 불변을 확인했다. 해당 경기 양쪽 수신 18,622,306바이트(상태·프로토콜 포함).

공개 주소의 독립 브라우저 두 탭: 로그인→자동 매칭→카운트다운→양쪽 이동·슛→한글 선수명→새로고침 후 동일 슬롯/기존 시계 복귀→0:2 자연 종료를 확인했다. 각각 패배/승리 및 결과 저장·성장 보상 없음 표시가 일치했다. 실제 화면 증거 artifacts/online-public.png, 서버 지표 artifacts/render-online-health.json. QA 계정은 검증 후 삭제했다.

이동·슛 80프레임 표시/서버 손바닥 대조 최대 오차 0.224mm. 뼈뿐 아니라 모델 루트 변환도 전송하며 캐시 접점을 갱신한다. 기존 AI rules/game/team_match/team_career_gameplay, 블록 반사, 웹 lifecycle 및 751개 문구×3번역 검사를 통과했다. 실제 공개 영어 매칭 안내와 취소도 확인했다.

Free 실측에는 여전히 CPU 선점 지연이 있다. 최종 경기에서 표본 1초 구간 p95 2.281~49.466ms, 표본 p99 최대72.355ms, Godot static 약47.2MB·Node RSS 약86.6~88.9MB였다. 60Hz 누적 과부하나 시계 지연은 발생하지 않았지만 Render에서 모든 구간 p95<16.7ms 목표를 충족했다고 주장하지 않는다. 100ms 표시 버퍼와 한 경기 수용량으로 첫 공개 시험을 운영한다. 전체 컨테이너 RSS·실기기·인위적 패킷 손실/250ms 지연·15분 유휴 cold start는 아직 별도 검증 대상이다. Android/Play 및 3대3 공개 완료가 아니다.
