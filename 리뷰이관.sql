-- 옛 시트 리뷰 → 주인장(싱성웡) 계정으로 이관
insert into public.reviews (place_id, user_id, rate, comment, visited_on) values
('pildonghambak', 'a03b89dc-700a-4003-951a-69ed784a099c', 1, '가격대비 별로임', '2026-08-18'),
('hwangpyeong', 'a03b89dc-700a-4003-951a-69ed784a099c', 3, '쏘쏘 가성비 좋은곳', '2026-08-18'),
('pildong', 'a03b89dc-700a-4003-951a-69ed784a099c', 4, '유명한 평냉집 촵', '2026-08-18'),
('chungpu', 'a03b89dc-700a-4003-951a-69ed784a099c', 4, '맛있음. 첫느낌 좋아요.', '2026-08-18'),
('chungmucurry', 'a03b89dc-700a-4003-951a-69ed784a099c', 3.5, '시그니쳐를 못먹어봐서 아직 모름. 한번 더 가봐야함', '2026-08-18')
on conflict (place_id, user_id) do update
  set rate = excluded.rate, comment = excluded.comment, visited_on = excluded.visited_on, updated_at = now();
