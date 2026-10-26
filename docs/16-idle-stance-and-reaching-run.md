# v0.8.9 · 대기 자세·긴 달리기·스킬 후 복귀

사용자 요청: 대기 화면의 교차한 다리,0.8.8의 종종걸음 대신 첨부한 원본 마네킹처럼 앞발을 뻗고 뒤꿈치를 회수하는 달리기, 드리블 스킬 후 마지막 스텝에 멈추지 않고 정상 대기로 돌아오기. Godot4.7.2 Standard/GDScript/Compatibility를 실행 파일과 프로젝트에서 재확인했다. 통합 PROJECT_BASELINE.md와 공통 개발 지침, 설치 router/목록 및 game-feel을 확인했다. 엔진·DB·인증은 유지한다.

## 원인과 수정

- reset_positions는0도 방향으로 발 접촉을 만든 뒤 facing=PI로 몸만 돌렸다. 메뉴에서 계속 animate하므로 양발 앵커가 뒤집힌 채 남았다. facing와 rotation을 먼저 맞춘 후 접촉을 초기화한다.
-0.8.8은 달리기 소스의 전후 발 궤적을72%, 발 높이를48%로 줄였다.98%/92%로 복원하고 일반 달리기 거리 기준0.96→1.30m, 최소 회수0.18→0.22초로 조정했다. 이동 속도·수비 스텝 시간은 그대로이며 같은 stride 위상으로 팔·다리·상체가 연결된다.
- 긴 첫 스텝 내내 반대 발을 고정하면 완전히 펴진 무릎이 다음 프레임에 급히 접혔다. 첫 회수의55%까지 지지한 뒤 정상 소스 이륙으로 넘긴다. 처음 발견한120Hz 무릎26.08m/s 실패는 검사를 완화하지 않고16.55m/s로 해결했다. 단순 발 목표 속도8→6 조정은 실패했으므로 채택하지 않았다.
- 드리블 스킬 후 idle은 마지막 발 앵커를 영구 유지했다. 정지하고 별도 접촉 동작이 끝나면 제자리에서 한 발씩 들어 어깨 너비의 대기 위치로 복귀한다. 움직이면 이 정돈을 기다리지 않고 달린다. 공을 두 손으로 잡은 축발·수비·착지는 기존 동작이 소유한다.
- 긴 달리기에서 턴 슛에 들어갈 때 뒤쪽 발의 world 목표 추적만으로는 회전한 몸 안쪽으로 경로가 잘렸다. 공 보유 turnshot에서 축발을 중심으로 실제 회전량만큼 자유 발을 운반한 뒤 목표로 닫는다. 이동 슛의 발 간격 실패12건을 해결했다.
- 초기 몸 회전을 정상화한 뒤 기존 턴 페이크가 우연한 몸 이동 없이도0.20초 안에 읽히도록 공의 측면 이동0.30→0.42m를 적용했다. 별도 슛 입력·속도·보상 규칙은 변경하지 않는다.

## 검증

- idle_stance_test: 실제 main scene/reset_positions, G/F/C·30/60/120Hz·3초, 최소 양발 간격0.400m·실패0. 최초 문제 재현은 반대 방향 몸 회전으로 최소 폭-0.534m/1,803실패였다. artifacts/v089-idle-before.txt, v089-final-idle_stance.txt.
- skill_idle_stance_test: A/Z/C/V/X×전/좌/우×30/60/120Hz45조건. 수정 전41조건이 잘못된 대기 위치로 남았고 최소 폭0.0137m였다. 수정 후 최소 폭0.3739m, 무릎17.15m/s 이하, 정돈 중 양발 동시 들기 없음·실패0. artifacts/v089-skill-idle-before.txt, v089-skill-idle-contacts.txt.
- run_contact_rhythm_test: 공 유/무·G/C·전/좌우45도·30/60/120Hz36조건. 동일 발 연속 착지0, 각 발의 최저 최대 높이0.4668m·최소 전후 궤적1.048m. 실제 소스 스킨 신발을 검사하며 숨은 프로토타입 발로 대체하지 않는다. artifacts/v089-stride-envelope.txt.
- leg_stability10,372샘플 실패0/무릎16.55m/s 이하; planted_cut108·cross_handoff36·defense_shuffle4,428프레임 실패0. artifacts/v089-leg-release.txt, v089-planted_cut.txt, v089-cross_handoff.txt, v089-defense_shuffle.txt.
- shot_entry288조건/52,832다리 프레임 실패0. 최소 준비 발 간격0.2634m, 무릎17.84m/s·손7.51m/s 이하. 기존 관절18m/s 기준과 발 접지 기준을 유지한다. shot_recovery48조건·wing_followthrough36조건·held_ball40·shot_skills24·snappy_fake62·team_match27항목 실패0. artifacts/v089-latest-*.txt, v089-snappy-final.txt.
- 실제 로컬 브라우저 연습에서 달리기→크로스오버/턴→정지 복귀, 캐릭터 스튜디오의 측면 달리기를 느린 보기로 확인했다.390×844 브라우저에서는 비하인드 후 서 있는 발과 터치 UI를 확인했다. 콘솔 warning/error0. artifacts/v089-cross-idle-gameplay.png, v089-run-side.png, v089-mobile-stance.png. 사용자 메인 경기는 초기화하지 않았다.
- 엔진 웹 export·셸 생성,678원문×3번역·웹 입력/수명주기 검사 통과. 의상 패키징의 첫 실패는 셸 생성 전에 검사해0.8.8 파일과 비교한 순서 오류이며 build_web 후 일치·통과했다.

실제 Android 기기·Play 출시·전체화면60fps 또는 모션의 미적 완성을 검증했다는 뜻은 아니다. 공개 결과는 배포 후 이어 기록한다.
