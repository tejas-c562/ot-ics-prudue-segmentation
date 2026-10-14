(* OpenPLC Structured Text program: tank level control.
   Use ONLY with the optional OpenPLC profile. Upload via the OpenPLC web UI
   (Programs -> Upload), compile, then Start PLC. Modbus/TCP server is on :502. *)
PROGRAM tank_level
  VAR
    pump_cmd AT %QX0.0 : BOOL;
    high_alarm AT %QX0.1 : BOOL;
    level_pv AT %IW100 : INT;     (* tank level x10 from the field/sim *)
    sp : INT := 600;              (* 60.0 % *)
  END_VAR
  pump_cmd := level_pv < (sp - 100);
  IF level_pv > (sp + 100) THEN pump_cmd := FALSE; END_IF;
  high_alarm := level_pv > 900;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms, PRIORITY := 0);
    PROGRAM instance0 WITH task0 : tank_level;
  END_RESOURCE
END_CONFIGURATION
