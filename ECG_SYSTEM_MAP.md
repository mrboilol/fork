# ECG system map

Server rhythm selection and cardiovascular ownership live in `lua/homigrad/organism/tier_1/modules/sv_pulse.lua`. `heartbeat` is electrical BPM; `pulse`, `cardiacOutput`, `strokeVolume`, and blood pressure remain mechanical outputs.

Existing rhythm identifiers are deliberately reused: `normal_sinus`, `sinus_bradycardia`, `sinus_tachycardia`, `compressed_tachycardia` (organized narrow SVT), `terminal_tachycardia` (ventricular tachycardia), `ventricular_ectopy` (PVCs), `atrial_fibrillation`, `ventricular_fibrillation`, `pea`, and `asystole`. Escape, hypothermia, cerebral, and AV-block states remain supported.

`GetECGState` applies rhythm priority and short hysteresis. It reserves PEA for organized electrical activity with negligible mechanical circulation, while asystole requires absent electrical activity.

The shared client renderer is `lua/autorun/client/cl_unconscious_ring.lua`; spectator and pulse-check displays call its exported ECG functions. Ischemia, tamponade electrical alternans, hypothermic J waves, PVC events, and fine/coarse VF are waveform modifiers rather than additional ECG states.
