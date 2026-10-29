# MotionBricks 이동 모션 적용

2026-10-29 · v0.10.9. 사용자 요청: 달리기·정지·방향 전환을 우선 실제 게임에 적용하고 검사·웹 배포·변경 기록을 남긴다.

## 실제 생성 경로

Godot 4.7.2 Standard / GDScript / Compatibility와 현재 45관절 인간형 리그를 유지한다. 설치된 MotionBricks 소스 `54fc563aeaaf819a753d72cc9fdc6713989cdd43`, SOMA FP32 모델과 ONNX Runtime CPU 실행을 확인했다. 이 PC는 CUDA를 지원하지 않으므로 CUDA 전용 공식 데모를 실행하거나 드라이버를 설치하지 않았다. `motionbricks`와 `roky-game-studio`의 네이티브 프로젝트 검증 기준을 사용했다.

공식 패키지의 BVH/CSV 및 기존 평가 결과는 출시 자산으로 사용하지 않는다. 게임에서 이미 사용하던 GDQuest / Luciano Muñoz 및 기여자의 CC BY 4.0 GLB만 입력으로 삼는다. SHA256 `8005cc2ab9221ad605be2d1cbb89eea894583e72bd5f50a5fbe40243a64f0493`. 모델·출처·실제 생성 측정은 `assets/motionbricks/provenance.json`, 권리 고지는 같은 폴더의 LICENSE.md에 기록했다.

1. `tools/export_motionbricks_source.gd`: 원본 GLB의 idle/run 전역 관절 자세와 rest를 추출한다.
2. `tools/author_motionbricks.py`: SOMA 77관절 참조 골격으로 회전 차이를 매핑한다. 최근 4프레임과 미래 4목표, 자체 작성한 이동 경로를 입력해 SOMA FP32로 실제 추론한다. 공식 인코더·디코더와 endpoint correction을 사용한다. 포함된 모션 샘플은 읽지 않는다.
3. 달리기 1개, 좌우 지지 발 정지 2개, 좌·우 회전 각 2개로 총 7클립 × 26프레임을 생성했다. 모델 출력의 실제 골반 축으로 매 프레임 전역 heading을 제거하고 원래 부모 좌표계의 로컬 quaternion으로 재타기팅한다.
4. `tools/bake_motionbricks_bank.gd`: 회전만 압축한 `assets/motionbricks/locomotion.res`를 만든다. 파일 크기는 124,954 bytes. 모델·Warp·ONNX Runtime은 게임에 포함하지 않는다.

이 생성은 개발 중 CPU에서 수행한다. 실제 측정한 추론 호출은 클립당 약 42~60ms이며 모델 적재·입출력·커널 준비 시간은 포함하지 않는다. 웹·Android 성능이나 실시간 추론 속도를 의미하지 않는다. 최초 커널 캐시는 설치 도구의 사용자 AppData 경로에 생성되었다. 생성 결과 폴더를 덮어쓰지 않도록 도구가 거부하며 재생성 시 새로운 프로젝트 내부 출력 경로를 지정한다.

재현 순서(설치된 CPU 환경 사용):

```powershell
& $godot --headless --path . --script tools/export_motionbricks_source.gd
& $cpuPython tools/author_motionbricks.py artifacts/motionbricks-authored-v2
& $godot --headless --path . --script tools/bake_motionbricks_bank.gd
```

기존 결과가 있으면 두 번째 명령에 새 경로를 쓰고 bake 도구의 입력 경로도 그 결과에 맞춘다. 공식 CUDA 앱이나 공식 내보내기 기능을 사용했다고 주장하지 않는다. 이 프로젝트가 작성한 CPU 어댑터와 Godot 재타기팅 경로다.

## 런타임 적용 범위

`scripts/motionbricks_pose.gd`를 실제 `RiggedStreetVisual`의 기본 포즈 샘플 뒤, 기존 접촉 IK 앞에 연결했다. 실제 변경 대상은 골반·척추·쇄골·위팔·아래팔 9관절의 회전이다. 보행 접촉 위상으로 달리기를 샘플링하며 지지 발과 방향을 보고 stop/left/right 변형을 고른다. 전환은 생성 클립과 달리기 사이의 연속 가중치로 연결하고 관절 회전 차이를 제한·평활화한다. 순간 이동에는 상태를 초기화한다.

루트 이동 속도·입력 반응·방향 전환 판정은 게임이 소유한다. 생성된 다리 위치와 길이, 루트 이동은 복사하지 않는다. 기존 보폭과 번갈아 디디는 발, 발목·무릎 IK와 공을 누르고 받는 손 보정을 유지한다. **이번 적용은 생성 전신 모션으로 완전 교체한 것이 아니라 몸통·어깨·팔을 우선 적용한 혼합 방식**이다. 다음 단계의 다리 교체는 기존 접지와 동등한 검증 후 별도로 한다.

슛·레이업·크로스오버 등 기술, 낮은 수비·박스아웃·공을 모은 상태에는 해당 전용 포즈가 우선한다. 수비 추격 중 일반 달리기에는 적용되며 헛디딤 회복 전용 동작에는 적용하지 않는다. 공 소유권·스틸·블록 접촉·육성·저장·서버 설정은 변경하지 않는다.

## 검사와 한계

- 새 `motionbricks_pose_test`: 7클립 8,190 quaternion 유한성·정규화, 달리기 루프 끝 연결, 30/60/120Hz × 공 유무 6시나리오의 실제 run/stop/left/right 선택, 모든 관절 유한성, 실제 척추 회전 변경과 슛 우선권 확인.
- `run_contact_rhythm`: 36조합, 같은 발 연속 착지 0회. 최소 뒤꿈치 회수 높이 약 0.483m, 전후 발 이동 폭 약 1.365m. 변경 전과 동일한 교대 순서를 유지한다.
- `planted_cut`: 108조합, 4,108개의 연속 지지 발 샘플에서 최대 이동 약 0.000002m.
- `stop_cut`: 24조합, 최대 지지 발 이동 약 0.00000072m. `cut_response`: 72조합, 응답 최대 0.167초, 정지 지연 0초.
- `leg_stability`: 10,372샘플 통과. `running_finish`, `dribble_feel`, `cross_handoff`, `run_silhouette` 통과. `motion_cache`: 15,000 actor샘플, 손·발 궤적 차이 0m, 관절 위치 차이 약 0.00000027m.

전체 검사가 모두 통과했다고 보고하지 않는다. `low_run_test`는 렌더된 skinned 발 대신 이전 procedural `shoes`를 읽으며 변경 전/후 모두 실패 608회·최대 이동 0.726m로 동일했다. 실제 skinned 신발 검사는 위의 contact/leg 검사로 수행한다. `ball_arm_anatomy_test`는 변경 전에도 실패 143회와 최대 팔꿈치 속도 45.47m/s가 있었다. 최종 결과는 실패 108회·최대 52.39m/s로, 총 실패 수는 줄었지만 최대 순간 속도는 커졌다. 일부 급전환 팔·손목 경계 문제가 남아 있으며 이 수치를 개선 완료로 해석하지 않는다. 이 검사를 완화하거나 완전 해결로 기록하지 않는다. 시각적인 팔·손목과 다리 전체 자연스러움은 추가 개선 대상이다.

검사 로그·원본 생성 결과는 `artifacts/mb-*`, `artifacts/motionbricks-authored-v2/`에 보관하며 배포하지 않는다. Windows 사용자 로그·루트 인증서 저장소 접근 경고가 있었고 이를 게임 검사 성공 항목에 포함하지 않았다. Android 실기기·Play 빌드는 이번에 검사하지 않았다.

## 브라우저와 공개 확인

사용자의 8791 경기 탭을 재시작하지 않고 별도 8804 미리보기에서 실제 캐릭터 스튜디오의 측면 달리기와 컷·급정지를 확인했다. 무릎·발의 교대, 어깨와 몸통 회전, 공과 손의 연결을 여러 시점에서 관찰했다. 자유 연습에서 방향키 이동→90도 전환→입력 해제 정지를 확인했고, 보상 없는 AI3대3에서 여섯 선수의 이동을 확인했다. 브라우저 오류 로그 0. 390×844 모바일 뷰포트에서는 실제 문서 폭/스크롤 폭이 모두375px로 가로 넘침이 없었고 터치 컨트롤을 유지했다. 실기기 성능 측정으로 해석하지 않는다.

증거: `artifacts/mb-running-side.png`, `mb-cut-front.png`, `mb-mobile-v0109.png`. 웹 내보내기와 셸 생성, JS/Python 구문·웹 lifecycle 검사 통과. 최종 공개 확인은 아래에 기록한다.
