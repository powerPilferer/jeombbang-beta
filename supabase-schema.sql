-- 점빵이 베타 스키마 v1 (2026-08-19)
-- 테이블: profiles(닉네임) / spots(내 장소·시각) / places(공용 식당 풀) / reviews / picks(추천·스킵 이력) / explore_requests(발굴 요청)

-- ── profiles: 점빵이 닉네임 (카카오 계정당 1개)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 12),
  created_at timestamptz not null default now()
);
create unique index profiles_nickname_uniq on public.profiles (lower(nickname));
alter table public.profiles enable row level security;
create policy "profiles 공개 읽기" on public.profiles for select using (true);
create policy "내 프로필 생성" on public.profiles for insert with check (auth.uid() = id);
create policy "내 프로필 수정" on public.profiles for update using (auth.uid() = id);

-- ── spots: 내 장소 + 반경 + 요일 + 받을 시각들
create table public.spots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 10),
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null check (radius_m between 100 and 20000),
  radius_label text not null default '',
  days text not null default 'always' check (days in ('weekday','weekend','always','custom')),
  custom_days smallint[] default null,
  meal_times jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.spots enable row level security;
create policy "내 장소만" on public.spots for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── places: 공용 식당 풀 (쓰기는 관리자 SQL로만)
create table public.places (
  id text primary key,
  name text not null,
  category text not null,
  menu text default '',
  price integer,
  menus jsonb not null default '[]'::jsonb,
  description text default '',
  hours text default '',
  tel text default '',
  note text default '',
  lat double precision not null,
  lng double precision not null,
  region text default '',
  slots text[] not null default '{lunch,dinner}',
  verified_at date,
  active boolean not null default true
);
alter table public.places enable row level security;
create policy "식당 풀 공개 읽기" on public.places for select using (active);

-- ── reviews: 가게당·사람당 1건
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id text not null references public.places(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rate numeric(2,1) not null check (rate >= 0.5 and rate <= 5),
  comment text not null default '' check (char_length(comment) <= 200),
  visited_on date not null default current_date,
  updated_at timestamptz not null default now(),
  unique (place_id, user_id)
);
alter table public.reviews enable row level security;
create policy "리뷰 공개 읽기" on public.reviews for select using (true);
create policy "내 리뷰 작성" on public.reviews for insert with check (auth.uid() = user_id);
create policy "내 리뷰 수정" on public.reviews for update using (auth.uid() = user_id);
create policy "내 리뷰 삭제" on public.reviews for delete using (auth.uid() = user_id);

-- ── picks: 추천·스킵 이력 (스킵 한도·반복 방지의 근거)
create table public.picks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pick_date date not null default current_date,
  slot text not null check (slot in ('breakfast','lunch','dinner','latenight')),
  place_id text not null references public.places(id) on delete cascade,
  status text not null default 'shown' check (status in ('shown','skipped')),
  created_at timestamptz not null default now()
);
alter table public.picks enable row level security;
create policy "내 이력만" on public.picks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── explore_requests: 이 동네 발굴 요청
create table public.explore_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  lat double precision not null,
  lng double precision not null,
  radius_m integer,
  slot text default '',
  note text default '',
  created_at timestamptz not null default now()
);
alter table public.explore_requests enable row level security;
create policy "발굴 요청 등록" on public.explore_requests for insert with check (auth.uid() = user_id);
create policy "내 요청 읽기" on public.explore_requests for select using (auth.uid() = user_id);

-- ── 식당 풀 시드: 충무로 13 + 마석 10
insert into public.places (id, name, category, menu, price, menus, description, hours, tel, note, lat, lng, region, slots, verified_at) values
('heungnam', '오장동흥남집 본점', '면', '회비빔냉면', 15000, '[]'::jsonb, '', '11:00–20:30 · L.O 20:00 · 브레이크 없음 · 수요일 휴무(수요일이 공휴일이면 목요일 휴무)', '02-2266-0735', '1953년 개업, 4대째 잇는 함흥냉면 노포 · 물냉면·고기비빔·섞임냉면 각 15,000원 · 100% 고구마 전분 면 · 2인 이상 묵정공원 30분 주차 지원', 37.5644188, 127.0005564, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('pildong', '필동면옥', '면', '평양냉면', 15000, '[]'::jsonb, '', '11:00–19:50 · 휴식 15:00–17:00', '', '', 37.5603894, 126.9969309, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('tsuyakatsu', '츠야카츠 충무로본점', '돈까스', '안심돈까스정식', 13900, '[]'::jsonb, '', '11:00–21:00 · 휴식 15:00–17:00 · L.O 20:30', '0507-1332-0253', '', 37.5625066, 126.9921619, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('jjukkumi', '충무로쭈꾸미불고기', '고기', '쭈꾸미 불고기', 18000, '[]'::jsonb, '', '12:00–22:00 · 브레이크 없음 · 일요일 휴무', '02-2279-0803', '', 37.561729, 126.9921675, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('pildonghambak', '필동함박 충무로 본점', '함박', '투움바 함박 스테이크', 13500, '[]'::jsonb, '', '매일 10:30–21:00 · L.O 20:15 · 브레이크타임 표기 없음', '0507-1401-6608', '백종원 골목식당 출연 · 주차 불가 · 점심시간 웨이팅 후기 있음', 37.5608512, 126.9962685, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('chungpu', '충푸', '중식', '유린기', 19000, '[]'::jsonb, '', '평일 11:00–22:00 · 휴식 15:00 무렵–17:00 · L.O 21:00 · 토 17:00–22:00 · 일 휴무', '0507-1396-9914', '2024년 9월 오픈한 중식 다이닝 · 매장이 작아 웨이팅 가능 · 점심·저녁 메뉴 구분', 37.5624231, 126.9951264, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('jingogae', '진고개', '국물', '갈비탕', 15000, '[]'::jsonb, '', '11:00–21:00 · 휴식 15:00–17:00 · 일요일 휴무', '02-2267-0955', '1963년 개업한 충무로 한식 노포 · 육개장 14,000원 · 물냉면 13,000원 · 갈비찜정식 24,000원은 예산 초과', 37.5630127, 126.9928333, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('hwangpyeong', '황평집', '국물', '닭곰탕', 9000, '[]'::jsonb, '', '11:00–21:30 · 휴식 15:30–17:00(~17:30 표기도 있음) · 일 휴무', '02-2266-6875', '', 37.5640375, 126.9961226, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('chungmucurry', '충무커리', '카레', '치킨윙토마토커리', 12900, '[]'::jsonb, '', '평일 11:00–20:00 · 휴식 14:30–17:00 · L.O 19:30 · 토·일 휴무', '010-3762-5379', '르 꼬르동 블루 출신 셰프의 일본식 수제 카레 · 2층 소규모 매장(약 15석) · 키오스크 주문 · 주차 불가', 37.5630091, 126.9913932, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('honam', '호남식당', '고기', '충무로 돼지물갈비', 15000, '[]'::jsonb, '', '12:00–22:30 · 브레이크타임 표기 없음 · 일요일 휴무 — 화요일 17시 영업 중(2026-08-18 확인, 식신은 13:00 오픈 표기)', '02-2273-1348', '1984년 개업한 물갈비(쫄갈비) 노포 · 백종원의 3대천왕 소개 · 돼지갈비 12,000원 · 야채찜돼지갈비 14,000원 · 볶음밥 5,000원(셀프 2,000원) · 라스트오더는 출처에 없어 미확인', 37.5628028, 126.9952662, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('buja', '부자돈까스', '돈까스', '부자돈까스', 10000, '[]'::jsonb, '', '평일 11:00–20:30 · 휴식 15:00–17:00 · L.O 19:30 · 토 휴무 · 일 10:30–14:00 — 화요일 17시는 저녁 영업 시작(2026-08-18 확인)', '02-2271-2328', '을지로·충무로 직장인이 찾는 옛날 경양식 돈까스 · 생선까스 10,000원 · 모듬까스 11,000원 · 카레돈까스 11,000원 · 점심시간 웨이팅 많음 · 영업시간이 출처 간 갈려(매일 11:00–21:00 표기도 있음) 방문 전 전화 확인 권장', 37.5642386, 126.9897922, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('nangman', '낭만짬뽕', '중식', '짬뽕', 9000, '[]'::jsonb, '', '11:00–20:30 · 휴식 15:00–17:00 · 휴무일 출처 갈림(마지막 주 토 또는 토·일) — 화요일은 영업', '02-2273-4458', '충무로 짬뽕 노포 · 홍합짬뽕 10,000원 · 냉짬뽕 11,000원 · 군만두 6,000원 · 식신에는 짬뽕 8,000원 표기라 가격은 방문 전 확인', 37.5627021, 126.9906845, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('phoeon', '포언', '아시아', '분짜', 14000, '[]'::jsonb, '', '매일 11:00–21:00 · L.O 20:30 · 휴무 없음', '0507-1406-3996', '베트남 쌀국수 전문점 · 양지차돌쌀국수 11,000원 · 반쎄오 후기 좋음 · 브레이크타임은 다이닝코드 기준 없음(일부 후기 15:00–16:30 표기)이나 어느 쪽이든 17시는 영업 중', 37.5623854, 126.9917454, 'chungmuro', '{lunch,dinner}', '2026-08-19'),
('galbi-damso', '갈비명가담소', '고기', '수제돼지갈비', 19000, '[{"name": "수제돼지갈비", "price": 19000}, {"name": "왕갈비(350g)", "price": 19000}, {"name": "소양념갈비살(180g)", "price": 19000}, {"name": "양념맛구이(250g)", "price": 16000}, {"name": "LA양념갈비(250g)", "price": 26000}]'::jsonb, '마석로변에 자리한 숯불 돼지갈비 전문점 — 가족 외식용 갈비 맛집으로 매장 앞 주차장이 있다', '매일 11:00–22:00 · L.O 21:30 · 브레이크 없음 (2026-08-19 확인)', '031-594-6700', 'L.O가 출처 간 갈림(다이닝코드 프로필 21:30 / 검색 요약 21:00) — 늦은 방문은 전화 확인 권장 · 매장 앞 주차 가능 · 좌표는 다이닝코드(rid=P4Nw5ijK6Y47)', 37.6574914, 127.3061761, 'maseok', '{lunch,dinner,latenight}', '2026-08-19'),
('ppongchai', '뽕차이 마석점', '중식', '짬뽕', 11000, '[{"name": "짬뽕", "price": 11000}, {"name": "중화비빔밥", "price": 9000}, {"name": "탕수육", "price": 10000}]'::jsonb, '마석역 3분 거리의 가성비 중화요리집 — 탕수육 1만원이 대표 인기 조합', '11:00–20:30 · 휴식 14:30–15:30 · 금요일 휴무 (2026-08-19 확인)', '031-591-6048', '짜장면 가격은 출처마다 7,000~9,000원대로 갈려 미확정 · 주차 불가(주변 유료주차장) · 좌표는 다이닝코드(rid=XBAZvFcfryiZ)', 37.651772, 127.3083447, 'maseok', '{lunch,dinner}', '2026-08-19'),
('twins-haejangguk', '쌍둥이해장국 마석점', '국물', '선지해장국', 13000, '[{"name": "해장국", "price": 13000}, {"name": "곰탕", "price": 13000}, {"name": "양볶음", "price": 28000}, {"name": "모듬수육", "price": 40000}]'::jsonb, '새벽 6시에 문 여는 선지해장국 전문점 — 아침 해장부터 저녁 수육 자리까지 다 되는 마석의 국밥 기둥', '매일 06:00–22:00 · L.O 21:20 (2026-08-19 확인)', '031-511-5011', '무료주차 가능(주차 관리자 배치) · 1인 1메뉴 · 좌표는 다이닝코드(rid=w7SMg5cuWVac)', 37.6511544, 127.313252, 'maseok', '{breakfast,lunch,dinner,latenight}', '2026-08-19'),
('haku-ramen', '하쿠라멘왕 마석점', '라멘', '돈코츠라멘', 9500, '[{"name": "돈코츠라멘", "price": 9500}, {"name": "우삼겹라멘", "price": 10500}, {"name": "연어롤", "price": 13000}, {"name": "에이세트(라멘+연어롤 반)", "price": 13900}, {"name": "연어덮밥", "price": 10000}]'::jsonb, '마석에서 드문 일본식 라멘집 — 돈코츠·간장 라멘에 연어롤 세트 조합이 인기', '11:00–20:30 · 평일 휴식 15:00–16:30 · 화요일 휴무 (2026-08-19 확인)', '0507-1344-2778', '테이블링 예약 페이지 있음 · 좌표는 다이닝코드(rid=bujDkpKkdWzU)', 37.6514068, 127.306311, 'maseok', '{lunch,dinner}', '2026-08-19'),
('jeongsikdang', '정식당', '백반', '백반', 8000, '[{"name": "백반(1인)", "price": 8000}]'::jsonb, '된장찌개에 고등어구이·장조림까지 반찬이 상다리 휘게 나오는 8,000원 백반집 — 마석중앙로 평점 최상위', '11:00–21:00 · 일요일 휴무 (2026-08-19 확인)', '031-511-7703', '백반 단일 메뉴 구성이라 menus가 1개 · 반찬은 날마다 바뀜 · 주차 가능 · 브레이크타임 유무 미확인 · 좌표는 다이닝코드(rid=p8KYZQTl2Cwn)', 37.6522533, 127.3058563, 'maseok', '{lunch,dinner}', '2026-08-19'),
('abai-sundae', '아바이순대 마석본점', '국물', '순대국', 11000, '[{"name": "순대국", "price": 11000}, {"name": "얼큰순대국", "price": 12000}, {"name": "우거지순대국", "price": 12000}, {"name": "순대정식", "price": 18000}, {"name": "모듬순대", "price": 27000}]'::jsonb, '연중무휴 아바이순대 전문점 — 아침 9시(주말 8시)부터 여는 묵현리의 든든한 순대국집', '월–금 09:00–22:00 · 토·일 08:00–22:00 · L.O 21:30 · 연중무휴 (2026-08-19 확인)', '031-593-9978', '무료주차 가능 · 역에서 도보권 밖(비룡로 219, 묵현리)이라 차 이동 권장 · 좌표는 다이닝코드(rid=MnYXDViH0Cdl)', 37.6708954, 127.3019906, 'maseok', '{breakfast,lunch,dinner,latenight}', '2026-08-19'),
('seoul-kalguksu', '서울칼국수', '면', '사골칼국수', 10000, '[{"name": "칼국수", "price": 10000}, {"name": "물만두", "price": 5000}, {"name": "낙지볶음(중)", "price": 20000}, {"name": "낙지볶음(대)", "price": 30000}]'::jsonb, '1984년부터 41년째 사골육수로 끓이는 마석 손칼국수 노포 — 낙지볶음과 곁들이는 조합이 단골 공식', '월–토 10:00–17:00 · L.O 16:00 · 일 10:00–15:00 · 목요일 휴무 (2026-08-19 확인)', '0507-1324-1400', '점심 전용 — L.O 16시라 저녁 불가 · 영업시간이 출처 간 갈림(다이닝코드 10–17시 목 휴무 / 블로그류 10–21시 휴식 17–18시) — 다이닝코드 최신값 채택, 오후 늦게 갈 거면 전화 확인 · 건물 3층, 주차 협소(공영주차장 이용) · 좌표는 다이닝코드(rid=K3VD9Voc75Kr)', 37.6533851, 127.3069222, 'maseok', '{lunch}', '2026-08-19'),
('gulttuk-baeksuk', '굴뚝능이버섯백숙', '한식', '능이버섯닭백숙', 80000, '[{"name": "능이버섯닭백숙", "price": 80000}, {"name": "능이버섯오리백숙", "price": 80000}, {"name": "능계탕", "price": 18000}, {"name": "평일 점심특선(갈치조림·불고기·김치찌개 등)", "price": 10000}, {"name": "생선구이 2인세트", "price": 34000}]'::jsonb, '검고 진한 능이버섯 국물의 백숙 전문점 — 룸이 있어 가족 모임·보양 외식에 맞고, 평일 점심엔 1만원 특선도 한다', '매일 10:30–21:30 · 설·추석 당일 휴무 · 평일 점심특선은 15시까지 (2026-08-19 확인)', '031-594-3311', '백숙 80,000원은 2~4인 기준 대형 메뉴 — 인원 적으면 능계탕 권장 · 무료주차(앞 5~10대, 뒤 약 10대) · 좌표는 OSM 노드 9092994905와 다이닝코드(rid=0bipsvjt48i6)가 1m 이내 일치로 교차검증', 37.6600734, 127.2914085, 'maseok', '{lunch,dinner}', '2026-08-19'),
('hwado-bunsik', '화도분식', '분식', '국물떡볶이', 5000, '[{"name": "국물떡볶이", "price": 5000}, {"name": "수제튀김(모듬)", "price": 6000}, {"name": "꼬마김밥", "price": 6000}, {"name": "순대", "price": 5000}, {"name": "오뎅", "price": 4000}]'::jsonb, '고추장 대신 직접 담근 다데기를 숙성해 쓰는 떡볶이집 — 매일 아침 육수를 새로 내는 마석장터 곁 분식집', '월–금 11:00–00:30 · 일 11:00–22:30 · 토요일 휴무 (2026-08-19 확인)', '0507-1428-3840', '영업시간이 출처 간 갈림(다이닝코드 11:00–00:30 / 검색 요약 11:30–22:30) — 심야 방문은 전화 확인 권장 · 별나라프라자 105호 · 좌표는 다이닝코드(rid=hE1Th1G3wq8z)', 37.656765, 127.3033424, 'maseok', '{lunch,dinner,latenight}', '2026-08-19'),
('taehee-donkatsu', '태희돈까스', '돈까스', '수제 등심돈까스', 11000, '[{"name": "수제 등심돈까스(2장)", "price": 11000}, {"name": "치즈 등심돈까스", "price": 10500}, {"name": "수제 함박스테이크", "price": 12000}, {"name": "제육덮밥", "price": 10000}]'::jsonb, '동네 사랑방 같은 수제돈까스집 — 등심 2장에 1만원 초반, 배달 위주지만 매장 식사도 된다', '매일 10:30–20:00 · 연중무휴 (2026-08-19 확인)', '031-592-3373', '배달 비중이 큰 가게라 매장 좌석은 소규모 · 반찬·장국·물 셀프 · 라스트오더 미확인 · 좌표는 다이닝코드(rid=2aAuhFwk5uxU)', 37.6549328, 127.3000487, 'maseok', '{lunch,dinner}', '2026-08-19');

-- ── wishes: 가보고 싶은 곳 (찜). 본인만 읽고 쓴다 — 고르는 목록이 아니라 기억
create table public.wishes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  place_id text not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);
alter table public.wishes enable row level security;
create policy "내 찜 읽기" on public.wishes for select using (auth.uid() = user_id);
create policy "내 찜 추가" on public.wishes for insert with check (auth.uid() = user_id);
create policy "내 찜 삭제" on public.wishes for delete using (auth.uid() = user_id);

-- 같은 끼니에 같은 집이 두 번 저장되는 것 방지 (두 기기가 동시에 열려 있을 때 발생)
create unique index picks_uniq on public.picks (user_id, pick_date, slot, place_id);
