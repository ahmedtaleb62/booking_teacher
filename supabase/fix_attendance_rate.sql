-- Recalculates attendance_rate for a teacher based on COMPLETED vs TEACHER_NO_SHOW sessions.
-- attendance_rate = COMPLETED / (COMPLETED + TEACHER_NO_SHOW) * 100, defaulting to 100 when no sessions.
CREATE OR REPLACE FUNCTION recalc_attendance_rate(p_teacher_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_completed  INT;
  v_no_shows   INT;
  v_rate       NUMERIC(5,2);
BEGIN
  SELECT
    COUNT(*) FILTER (WHERE state = 'COMPLETED'),
    COUNT(*) FILTER (WHERE state = 'TEACHER_NO_SHOW')
  INTO v_completed, v_no_shows
  FROM sessions
  WHERE teacher_id = p_teacher_id;

  IF (v_completed + v_no_shows) = 0 THEN
    v_rate := 100.0;
  ELSE
    v_rate := ROUND(100.0 * v_completed / (v_completed + v_no_shows), 2);
  END IF;

  UPDATE teacher_profiles SET attendance_rate = v_rate WHERE id = p_teacher_id;
END;
$$;

-- Trigger function that hooks into COMPLETED and TEACHER_NO_SHOW state transitions.
CREATE OR REPLACE FUNCTION trg_update_attendance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.state IN ('COMPLETED', 'TEACHER_NO_SHOW')
     AND OLD.state <> NEW.state THEN
    PERFORM recalc_attendance_rate(NEW.teacher_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_attendance_rate ON sessions;

CREATE TRIGGER trg_attendance_rate
  AFTER UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION trg_update_attendance();

-- Back-fill existing teachers so historical data is reflected immediately.
SELECT recalc_attendance_rate(id) FROM teacher_profiles;
