-- Altos founder pipeline: applications + Turing AI interview + meeting completion.
-- Optional :since parameter; defaults to last 30 days.
SELECT aa.room_id,
       a.created_at  AS applied_at,
       a.founder_name,
       a.founder_email,
       a.founder_phone,
       a.founder_current_location,
       a.founder_role,
       a.founder_linkedin,
       aa.created_at AS conversation_at,
       m.is_completed,
       aa.conversation_id,
       aa.ps_summary,
       aa.cap_table,
       a.pitch_deck_url AS pitch_deck,
       aa.elevator_pitch,
       aa.problem,
       aa.solution,
       aa.traction,
       aa.commercial,
       aa.market_size,
       aa.competition,
       aa.fundraising_status,
       aa.video_url,
       aa.transcript
FROM altos_application a
LEFT JOIN altos_attempts aa ON a.altos_interview_id = aa.turing_interview_id
LEFT JOIN meeting        m  ON m.channel_id          = aa.room_id
WHERE a.created_at >= COALESCE(%(since)s::timestamptz, NOW() - INTERVAL '30 days')
  AND m.is_completed IN ('COMPLETED', 'PARTIALLY_COMPLETE')
ORDER BY a.created_at DESC;
