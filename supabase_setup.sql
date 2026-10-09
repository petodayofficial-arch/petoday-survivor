-- 펫 서바이버 랭킹 서버 (Supabase) 초기 설정
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 Run

create extension if not exists pgcrypto;

-- 1) 점수 테이블 (contact = 인스타 아이디, 외부에 노출되지 않음)
create table if not exists public.scores (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  nickname    text not null check (char_length(nickname) between 2 and 10 and nickname !~ '[<>]'),
  contact     text check (contact is null or char_length(contact) <= 30),
  pet         text not null check (pet in ('pari','kong','siri','reo')),
  time        integer not null check (time between 30 and 7200),      -- 생존 초 (최대 2시간)
  score       integer not null check (score >= 0 and score <= time * 40), -- 시간 대비 비정상 점수 차단
  lv          integer check (lv between 1 and 200),
  kills       integer check (kills between 0 and 200000),
  client_id   text,
  version     text
);
create index if not exists scores_time_idx on public.scores (time desc, score desc);
create index if not exists scores_client_idx on public.scores (client_id, created_at desc);

-- 2) 공개용 뷰: 닉네임당 최고 기록 1개만, 연락처 제외
create or replace view public.leaderboard with (security_invoker = false) as
  select distinct on (lower(nickname)) nickname, pet, time, score, created_at
  from public.scores
  order by lower(nickname), time desc, score desc, created_at asc;

-- 3) 권한: 익명(anon)은 scores에 INSERT만, leaderboard는 SELECT만
alter table public.scores enable row level security;
drop policy if exists "anon insert" on public.scores;
create policy "anon insert" on public.scores for insert to anon with check (true);
revoke all on public.scores from anon;
grant insert on public.scores to anon;
grant select on public.leaderboard to anon;

-- 4) 도배 방지: 같은 기기(client_id)는 1분에 3건까지
create or replace function public.scores_rate_limit() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.client_id is not null and (select count(*) from public.scores where client_id = new.client_id and created_at > now() - interval '1 minute') >= 3 then
    raise exception 'rate limit';
  end if;
  return new;
end $$;
drop trigger if exists scores_rate_limit_trg on public.scores;
create trigger scores_rate_limit_trg before insert on public.scores for each row execute function public.scores_rate_limit();

-- 당첨자 확인용 (대시보드에서 실행): 1~5위 + 연락처
-- select nickname, contact, pet, time, score, created_at from public.scores
--   where id in (select distinct on (lower(nickname)) id from public.scores order by lower(nickname), time desc, score desc)
--   and created_at <= '2026-10-20 23:59:59+09' order by time desc, score desc limit 5;

-- 5) 친구 초대 (추천인): 초대받은 기기 1대당 1건, 3분 이상 플레이 + 닉네임 등록 시 기록
create table if not exists public.referrals (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  referrer       text not null check (char_length(referrer) between 2 and 10),
  invitee_client text not null unique,
  invitee_nick   text check (invitee_nick is null or char_length(invitee_nick) <= 10),
  play_time      integer not null check (play_time >= 180)
);
create index if not exists referrals_referrer_idx on public.referrals (lower(referrer));
create or replace view public.referral_counts with (security_invoker = false) as
  select lower(referrer) as referrer_key, min(referrer) as referrer, count(*)::int as invites
  from public.referrals group by lower(referrer) order by invites desc;
alter table public.referrals enable row level security;
drop policy if exists "anon insert ref" on public.referrals;
create policy "anon insert ref" on public.referrals for insert to anon with check (true);
revoke all on public.referrals from anon;
grant insert on public.referrals to anon;
grant select on public.referral_counts to anon;
