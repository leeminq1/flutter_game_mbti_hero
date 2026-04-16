create table if not exists public.leaderboard_entries (
  id bigint generated always as identity primary key,
  nickname text not null,
  nickname_normalized text not null,
  character text not null,
  companion text not null,
  wave integer not null,
  score integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint leaderboard_entries_wave_check check (wave >= 1),
  constraint leaderboard_entries_score_check check (score >= 0),
  constraint leaderboard_entries_nickname_length_check
    check (char_length(btrim(nickname)) between 1 and 12)
);

create unique index if not exists leaderboard_entries_nickname_normalized_key
  on public.leaderboard_entries (nickname_normalized);

create index if not exists leaderboard_entries_rank_idx
  on public.leaderboard_entries (wave desc, score desc, created_at desc);

alter table public.leaderboard_entries enable row level security;

drop policy if exists "leaderboard_read_access" on public.leaderboard_entries;
create policy "leaderboard_read_access"
  on public.leaderboard_entries
  for select
  to anon
  using (true);

revoke all on public.leaderboard_entries from public;
revoke all on public.leaderboard_entries from anon;
revoke all on public.leaderboard_entries from authenticated;
grant select on public.leaderboard_entries to anon;

create or replace function public.submit_leaderboard_entry(
  p_nickname text,
  p_character text,
  p_companion text,
  p_wave integer,
  p_score integer,
  p_created_at timestamptz default null
)
returns public.leaderboard_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nickname text := btrim(coalesce(p_nickname, ''));
  v_normalized text := lower(v_nickname);
  v_entry public.leaderboard_entries;
begin
  if char_length(v_nickname) = 0 then
    raise exception using errcode = '22023', message = 'nickname_required';
  end if;

  if char_length(v_nickname) > 12 then
    raise exception using errcode = '22023', message = 'nickname_too_long';
  end if;

  if p_wave < 1 then
    raise exception using errcode = '22023', message = 'invalid_wave';
  end if;

  if p_score < 0 then
    raise exception using errcode = '22023', message = 'invalid_score';
  end if;

  insert into public.leaderboard_entries (
    nickname,
    nickname_normalized,
    character,
    companion,
    wave,
    score,
    created_at
  )
  values (
    v_nickname,
    v_normalized,
    p_character,
    p_companion,
    p_wave,
    p_score,
    coalesce(p_created_at, timezone('utc', now()))
  )
  returning * into v_entry;

  return v_entry;
exception
  when unique_violation then
    raise exception using errcode = '23505', message = 'duplicate_nickname';
end;
$$;

revoke all on function public.submit_leaderboard_entry(
  text,
  text,
  text,
  integer,
  integer,
  timestamptz
) from public;
grant execute on function public.submit_leaderboard_entry(
  text,
  text,
  text,
  integer,
  integer,
  timestamptz
) to anon;
