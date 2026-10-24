# 제작과 사용 고지

- 코트·공·아이콘과 이전 절차적 캐릭터: 이 프로젝트에서 작성한 메시와 SVG. v0.6.23부터 실제 경기 캐릭터의 임시 스킨 리그는 아래 GDQuest 자산을 사용한다.
- 캐릭터 표면: 내장 `image_gen.imagegen`으로 2026-10-24 생성한 [텍스처 아틀라스](assets/textures/street-atlas-v04.png). [전체 프롬프트와 생성 방식](assets/textures/street-atlas-v04.prompt.txt). 얼굴·저지·면 티셔츠·데님을 자체 메시의 UV에 매핑했다. 원작 게임의 텍스처를 추출하거나 사용하지 않았다.
- 효과음: `tools/generate_audio.py`에서 직접 합성. 외부 녹음이나 원작 음원을 사용하지 않음.
- 화면 글꼴: 기기에 설치된 시스템 글꼴을 사용하며 글꼴 파일을 재배포하지 않음.
- 엔진: **Godot Engine**, MIT License. Copyright (c) 2014-present Godot Engine contributors; Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Godot 라이선스 전문과 포함 라이브러리의 고지는 [Godot 공식 라이선스 페이지](https://godotengine.org/license/)와 [엔진 저작권 고지](https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt)를 참조한다.

프리스타일은 작화와 플레이 감각을 이해하기 위한 참고 작품이다. 본 시제품의 캐릭터·로고·코트·음원은 별도로 작성했다.

최종 아틀라스는 사진 같은 초안을 손으로 그린 셀 셰이딩으로 수정했다. 현재 파일에 대응하는 [최종 편집 프롬프트](assets/textures/street-atlas-v04-final.prompt.txt)를 함께 보관한다.

## 경기용 임시 리그와 모션 비교

- `assets/experiments/mannequiny/mannequiny.glb`: **GDQuest and contributors (https://www.gdquest.com/)**. Character design, rig and animation by Luciano Muñoz. Art asset license: **CC BY 4.0**. [공식 저장소](https://github.com/gdquest-demos/godot-3d-mannequin), [원본 라이선스 사본](assets/experiments/mannequiny/LICENSE.txt), [고정 커밋·SHA256·취득 기록](assets/experiments/mannequiny/provenance.json).
- 원본 GLB는 수정하지 않았다. Godot 4.7.2로 가져와 비교 장면과 실제 경기에서 사용한다. 경기용 색상, 뼈 스케일 고정, 달리기/대기 재생 전환, 드리블·발 접촉 IK와 방향 전환 위상 보정을 런타임에 적용했다. 원 저장소의 Godot 3 컨트롤러 코드는 가져오지 않았다.
- 이 마네킹은 최종 코트러시 캐릭터나 제작 완료된 농구 애니메이션이 아니다. 업데이트 안내와 모션 비교 페이지에서 출처와 라이선스를 표시한다. 이전 절차적 캐릭터는 비교 장면과 숨겨진 접촉 목표 계산에 남아 있고 경기 화면에는 새 스킨 리그를 사용한다. 코트·공·음원은 위의 자체 제작 자산을 유지한다.

## v0.6.24 경기용 사람형 외형

- `assets/characters/rush_player.res`, `rush_rival.res`: 이 프로젝트에서 새로 작성한 사람형 피부·얼굴·머리카락·농구복·신발 메시. `tools/build_player_mesh.gd`에 편집 가능한 제작 소스를 보관한다. 저지 SVG와 `court_fabric.gdshader`도 자체 작성했다. 원작 게임 모델·사진 얼굴·의류 상표를 가져오지 않았다.
- 원본 GDQuest 리그의 inverse bind에 맞춰 새 메시를 스키닝했다. 화면에서 원본 마네킹 메시만 숨기며, **GDQuest and contributors / Luciano Muñoz, CC BY 4.0**의 리그·기본 클립은 계속 사용한다. 원본 GLB의 해시와 라이선스 사본을 유지하고 캐릭터 스튜디오와 업데이트 안내에도 출처를 표시한다.
- 이전 생성 아틀라스는 구형 캐릭터 비교용으로 남긴다. 새 사람형 외형은 해당 아틀라스를 얼굴에 덮어쓴 것이 아니며 자체 형상/정점 색/원단 셰이더/번호 SVG로 구성된다. [자산 출처·편집 기록](assets/characters/provenance.json), [제작/예산](assets/characters/README.md).

## v0.6.25 얼굴/의상 재제작

- `assets/characters/face-painted-v2.png`: 내장 **image_gen.imagegen**으로 새로 생성한 얼굴용 일러스트 텍스처. 최초 사실적 초안은 사용하지 않고, 수작업풍 편집 결과를 선택했다. [전체 생성/편집 프롬프트와 선택 기록](assets/characters/face-painted-v2.prompt.txt). 사진 인물이나 원작 캐릭터 텍스처를 가져오지 않았다.
- 얼굴·쇄골·팔·농구복 주름/허리-반바지 연결은 자체 메시 재제작이며, 새 얼굴 UV와 의상 UV2/법선으로 리그 변형을 따른다. 원본 GDQuest 리그/클립과 CC BY 4.0 고지는 유지한다. 원본 GLB 바이트는 바꾸지 않았다.
