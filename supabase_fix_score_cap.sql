-- 2026-10-21 기록 등록 실패 수정
-- 원인: scores 테이블의 "점수 <= 생존초 x 40" 규칙이 너무 낮아, 15분 이상 잘 버틴 기록이 400(check 위반)으로 거부됨
-- 적용: Supabase 대시보드 → SQL Editor → 아래 전체 붙여넣고 Run (한 번만)

do $$
declare c record;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.scores'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ~ '(score|kills|time|lv)'
  loop
    execute format('alter table public.scores drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.scores
  add constraint scores_time_check  check (time between 30 and 14400),
  add constraint scores_score_check check (score >= 0 and score <= 5000 + time*60 + (time*time)/10),
  add constraint scores_lv_check    check (lv is null or lv between 1 and 500),
  add constraint scores_kills_check check (kills is null or kills between 0 and 2000000);

-- 확인: 아래 결과에 scores_time_check / scores_score_check / scores_lv_check / scores_kills_check 4줄이 보이면 성공
select conname, pg_get_constraintdef(oid) from pg_constraint
 where conrelid = 'public.scores'::regclass and contype = 'c' order by conname;
