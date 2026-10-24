# 엔진 선택 기록

작성일: 2026-10-23 / 상태: 조사에 근거한 추천, 실제 성능 비교 전

## 1. 결론과 전제

**Godot 4.7.2 Standard, GDScript, Compatibility 렌더러를 추천한다.** 사용자에게 확인한 첫 배포 방식은 “웹에서 바로 플레이 — Roky Studio에서 쉽게 접속”이다. 모바일 브라우저도 고려하되, 초기 경기 감각 검증은 PC 브라우저와 키보드로 시작한다.

공식 홈페이지에서 현재 안정판으로 4.7.2를 확인했다. 에디터와 export template 버전은 반드시 일치시킨다. 개발 시작 시 보안·웹 관련 패치 여부를 재확인하고 채택한 정확한 버전을 고정한다. [Godot 공식 배포](https://godotengine.org/)

이는 모든 종류의 농구 게임에 대한 절대 순위가 아니다. 작은 팀의 제작 범위, 브라우저 공개, 툰 스타일 3D, 이후 설치형 확장을 함께 고려한 판단이다. 현재 폴더는 비어 있었으며 기존 엔진이나 코드에 맞춰야 할 제약은 없었다. 인접 프로젝트 `작은정원/PROJECT_PLAN.md`의 Godot 웹 배포 경험은 운영상의 참고로만 사용했다.

## 2. 비교

아래 적합도는 공식 기능 자료를 바탕으로 한 프로젝트별 판단이며 벤치마크 결과가 아니다.

| 후보 | 작화·캐릭터 제작 | 웹 배포 관점 | 직접 해결할 부분 | 이 프로젝트 판단 |
| --- | --- | --- | --- | --- |
| **Godot 4** | 툰 재질, 스켈레탈 애니메이션, AnimationTree로 필요한 표현 구성 가능 | 웹 내보내기와 정적 HTML 연결 가능 | 모바일 성능, 외곽선 비용, 온라인 예측·보정 | **첫 선택**. 게임 전용 제작 도구와 웹·설치형 확장 균형 |
| **Unity 6 + URP** | 렌더 파이프라인과 캐릭터 제작 도구가 유력한 장점 | 웹 빌드 가능. 브라우저 통신 제약은 별도로 존재 | 빌드·패키지 관리, 웹 메모리 및 로딩, 네트워크 구성 검증 | PC 중심 온라인 대전으로 방향이 바뀌면 우선 재검토 |
| **PlayCanvas** | 웹 3D 엔진, 애니메이션·물리 기능 제공 | WebGPU/WebGL 2와 JS 생태계에 직접 연결 | 농구 시뮬레이션, 온라인 판정, 제작 도구 구성 | 웹 전용·JS 개발을 최우선하면 강한 대안 |
| **Unreal Engine** | 고급 3D 및 애니메이션 제작 후보 | 공식 HTML5 지원은 과거 커뮤니티로 이관. Pixel Streaming은 서버에서 렌더링 | 웹 경로 유지보수 또는 GPU 서버 운영 | 이번 가벼운 정적 웹 공개에는 비추천 |

근거: [Godot 툰 재질](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html), [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html), [Unity URP](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/urp-introduction.html), [Unity 웹 네트워킹](https://docs.unity.com/en-us/engine/6000.6/manual/platform-specific/webgl/develop/networking), [PlayCanvas Engine](https://developer.playcanvas.com/user-manual/engine/), [Epic HTML5 이관 안내](https://www2.unrealengine.com/blog/unreal-engine-4-23-released), [현재 Pixel Streaming 설명](https://dev.epicgames.com/documentation/en-us/unreal-engine/pixel-streaming-in-unreal-engine).

## 3. Godot를 선택하는 이유

1. 이 게임의 핵심은 고가의 사실적 렌더링보다 캐릭터 실루엣, 명암 경계, 애니메이션 타이밍과 입력 반응이다. 이를 구현할 재질·애니메이션 도구가 있다.
2. 코트 하나와 여섯 캐릭터로 시작하면 렌더링 범위를 통제하기 좋다. 다만 성능 통과는 실기기 측정으로 결정한다.
3. GDScript·씬·리소스로 규칙과 동작 수치를 분리하고 빠르게 조정할 수 있다.
4. 웹판에서 검증한 자산과 규칙을 나중에 같은 엔진의 설치형으로 확장할 수 있다. 플랫폼별 입력·저장·통신 검증은 여전히 필요하다.
5. 엔진은 MIT 라이선스로 배포된다. 게임 크레딧에 엔진과 외부 자산의 고지 사항을 모은다. 엔진 사용 비용과 별개로 아트 제작·온라인 서버 비용은 발생할 수 있다. [Godot 라이선스](https://godotengine.org/license/)

## 4. 처음부터 반영할 웹 제약

- 공식 웹 내보내기는 WebAssembly와 WebGL 2를 사용하며 Compatibility 렌더러가 필요하다.
- Godot 4 C# 프로젝트의 웹 내보내기는 공식 문서상 지원되지 않으므로 GDScript를 사용한다.
- 첫 빌드는 단일 스레드로 내보낸다. 멀티스레드의 교차 출처 격리 헤더에 의존하지 않는 배포를 우선한다.
- 오디오 시작은 사용자의 시작 버튼 입력과 연결한다. 웹 오디오 재생 모드의 효과 제한을 고려해 완성된 효과음 파일을 준비한다.
- 휴대폰에서 설치형과 동일 성능을 가정하지 않는다. 해상도·외곽선·그림자 품질을 조절하고 실제 브라우저에서 확인한다.

위 제약의 기준: [Godot 웹 내보내기 공식 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## 5. 온라인은 엔진 선택만으로 해결되지 않는다

Godot 웹 환경은 WebSocket/WebRTC를 사용할 수 있지만 raw TCP/UDP에 직접 접근하지 못한다. 설치형 ENet 구현을 브라우저에 그대로 적용하지 않는다. [공식 멀티플레이 문서](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

프로토타입은 로컬 권위 시뮬레이션으로 만든다. 온라인 시험은 동일 규칙을 실행하는 전용 서버와 WSS 연결부터 시작한다. 지연·패킷 손실에서 WSS가 목표를 충족하지 못하면 WebRTC 데이터 채널과 서버 연동을 별도 검증한다. 전송 방식을 바꿔도 입력 예측, 서버 보정, 공 소유권 판정은 구현해야 한다.

Unity에도 웹 네트워킹 경로가 있으므로 “웹이면 Godot만 가능”하다는 이유로 선택하지 않는다. Unity 6.3 LTS와 6.6 Supported가 공식 자료에 확인되며, 이번 선택은 기능 유무보다 프로젝트 제작·운영 균형에 근거한다. [Unity 지원 정책](https://unity.com/releases/unity-6/support), [Unity 6.6 발표](https://discussions.unity.com/t/unity-6-6-is-now-available/1735357)

## 6. 선택을 검증하는 짧은 시험

본격적인 캐릭터·코트 양산 전에 다음을 검증한다.

- 여섯 스킨 메시, 툰 재질, 공, 그림자를 배치한 실제 웹 빌드 성능.
- 한 캐릭터의 드리블→슛 페이크→돌파→슛 동작과 손·공 접점.
- PC와 Android Chrome에서 시작·오디오·키보드/터치·화면 크기 변경.
- 두 클라이언트와 전용 서버에서 패스·블록·리바운드의 단일 판정.

최적화 후에도 목표 기기에서 읽기 쉬운 작화와 반응성을 유지할 수 없으면, 자산 제작을 늘리기 전에 PlayCanvas 비교 시제품을 만든다. PC 설치형 중심으로 바뀌면 Unity와 다시 비교한다.
