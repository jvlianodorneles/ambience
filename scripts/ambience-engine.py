#!/usr/bin/env python3
"""
Ambience Studio Engine for Omarchy
Hybrid Audio Synthesizer & Seamless Soundscape Player
"""

import sys
import os
import time
import math
import random
import struct
import signal
import json
import subprocess
import threading
from pathlib import Path

STATE_DIR = Path.home() / ".local" / "state" / "omarchy" / "ambience"
STATE_FILE = STATE_DIR / "state.json"
PID_FILE = STATE_DIR / "engine.pid"
PLUGIN_DIR = Path(__file__).resolve().parent.parent
SOUNDS_DIR = PLUGIN_DIR / "sounds"

SAMPLE_RATE = 44100

def ensure_state_dir():
    STATE_DIR.mkdir(parents=True, exist_ok=True)

def load_state():
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "playing": False,
        "preset": "rain",
        "volume": 60,
        "timer": 0,
        "timer_start": 0
    }

def save_state(state):
    ensure_state_dir()
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)

def is_ambience_process(pid: int) -> bool:
    """Verifies that the given PID is alive and actually belongs to this Ambience daemon."""
    try:
        cmdline_file = Path(f"/proc/{pid}/cmdline")
        if not cmdline_file.exists():
            return False
        raw = cmdline_file.read_bytes()
        cmdline = raw.decode("utf-8", errors="replace").replace("\x00", " ")
        if "ambience-engine.py" in cmdline and "_daemon" in cmdline:
            return True
        if "ambience-engine" in cmdline:
            return True
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return False
    except Exception:
        pass
    return False

def is_running():
    if PID_FILE.exists():
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            if is_ambience_process(pid):
                return pid
            # PID is recycled or belongs to an unrelated process
            PID_FILE.unlink(missing_ok=True)
        except (ProcessLookupError, ValueError):
            PID_FILE.unlink(missing_ok=True)
        except PermissionError:
            PID_FILE.unlink(missing_ok=True)
    return None

def stop_daemon():
    pid = is_running()
    if pid:
        try:
            if is_ambience_process(pid):
                os.kill(pid, signal.SIGTERM)
                time.sleep(0.15)
                try:
                    if is_ambience_process(pid):
                        os.kill(pid, signal.SIGKILL)
                except Exception:
                    pass
        except Exception:
            pass
        PID_FILE.unlink(missing_ok=True)
    state = load_state()
    state["playing"] = False
    state["timer"] = 0
    state["timer_start"] = 0
    save_state(state)

class AudioSynthesizer:
    """Real-time procedural DSP noise synthesizer"""
    def __init__(self, preset, volume):
        self.preset = preset
        self.volume = max(0.0, min(1.0, volume / 100.0))
        self.running = True
        self.sample_idx = 0

        # State variables for filters
        self.b0 = self.b1 = self.b2 = self.b3 = self.b4 = self.b5 = self.b6 = 0.0
        self.brown_last_l = 0.0
        self.brown_last_r = 0.0
        self.rain_last_l = 0.0
        self.rain_last_r = 0.0

    def set_volume(self, vol_percent):
        self.volume = max(0.0, min(1.0, vol_percent / 100.0))

    def set_preset(self, preset):
        self.preset = preset
        self.sample_idx = 0

    def generate_chunk(self, num_samples=2048):
        """Generates 16-bit stereo PCM chunk (little-endian)"""
        buffer = bytearray()
        gain = self.volume * 28000.0

        for _ in range(num_samples):
            self.sample_idx += 1
            t = self.sample_idx / SAMPLE_RATE

            if self.preset == "brown":
                # Brownian (red) noise: 6dB/octave dropoff
                w_l = random.uniform(-1.0, 1.0)
                w_r = random.uniform(-1.0, 1.0)
                self.brown_last_l = (self.brown_last_l + (0.02 * w_l)) / 1.02
                self.brown_last_r = (self.brown_last_r + (0.02 * w_r)) / 1.02
                out_l = self.brown_last_l * 3.2
                out_r = self.brown_last_r * 3.2

            elif self.preset == "pink":
                # Paul Kellet pink noise filter
                w = random.uniform(-1.0, 1.0)
                self.b0 = 0.99886 * self.b0 + w * 0.0555179
                self.b1 = 0.99332 * self.b1 + w * 0.0750759
                self.b2 = 0.96900 * self.b2 + w * 0.1538520
                self.b3 = 0.86650 * self.b3 + w * 0.3104856
                self.b4 = 0.55000 * self.b4 + w * 0.5329522
                self.b5 = -0.7616 * self.b5 - w * 0.0168980
                pink = self.b0 + self.b1 + self.b2 + self.b3 + self.b4 + self.b5 + self.b6 + w * 0.5362
                self.b6 = w * 0.115926
                out_l = pink * 0.14
                out_r = out_l

            elif self.preset == "waves":
                # Ocean waves: Slow sinusoidal modulation of deep brown surf
                # 11-second cycle with natural irregularity
                env = 0.15 + 0.85 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 11.0 + 0.2 * math.sin(2 * math.pi * t / 23.0))) ** 2
                w_l = random.uniform(-1.0, 1.0)
                w_r = random.uniform(-1.0, 1.0)
                self.brown_last_l = (self.brown_last_l + (0.03 * w_l)) / 1.03
                self.brown_last_r = (self.brown_last_r + (0.03 * w_r)) / 1.03
                out_l = self.brown_last_l * 3.0 * env
                out_r = self.brown_last_r * 3.0 * env

            elif self.preset == "rain":
                # Rain simulation: continuous pink/brown layer + droplet impulses
                w_l = random.uniform(-1.0, 1.0)
                w_r = random.uniform(-1.0, 1.0)
                self.rain_last_l = (self.rain_last_l + (0.08 * w_l)) / 1.08
                self.rain_last_r = (self.rain_last_r + (0.08 * w_r)) / 1.08
                
                # Droplets
                drop_l = random.uniform(-0.5, 0.5) if random.random() < 0.003 else 0.0
                drop_r = random.uniform(-0.5, 0.5) if random.random() < 0.003 else 0.0
                
                out_l = (self.rain_last_l * 1.8) + drop_l
                out_r = (self.rain_last_r * 1.8) + drop_r

            elif self.preset == "campfire":
                # Campfire: warm low-pass + crackles/pops
                w = random.uniform(-1.0, 1.0)
                self.brown_last_l = (self.brown_last_l + (0.015 * w)) / 1.015
                crackle = 0.0
                if random.random() < 0.0007:
                    crackle = random.uniform(-0.9, 0.9)
                elif random.random() < 0.004:
                    crackle = random.uniform(-0.25, 0.25)
                out_l = (self.brown_last_l * 2.2) + crackle
                out_r = out_l

            elif self.preset == "binaural":
                # 200 Hz base carrier, 10 Hz Alpha frequency offset (200 Hz left, 210 Hz right)
                base = 200.0
                diff = 10.0
                # Add a soft background brown noise bed
                w = random.uniform(-1.0, 1.0)
                self.brown_last_l = (self.brown_last_l + (0.01 * w)) / 1.01
                noise_bed = self.brown_last_l * 0.4

                sine_l = math.sin(2 * math.pi * base * t) * 0.4
                sine_r = math.sin(2 * math.pi * (base + diff) * t) * 0.4
                out_l = sine_l + noise_bed
                out_r = sine_r + noise_bed

            elif self.preset == "cafe":
                # Café ambient chatter / acoustic filter
                w_l = random.uniform(-1.0, 1.0)
                w_r = random.uniform(-1.0, 1.0)
                self.b0 = 0.95 * self.b0 + w_l * 0.05
                self.b1 = 0.95 * self.b1 + w_r * 0.05
                mod_l = 0.5 + 0.5 * math.sin(2 * math.pi * 0.3 * t)
                out_l = self.b0 * 1.8 * (0.8 + 0.2 * mod_l)
                out_r = self.b1 * 1.8
            else:
                # White noise default
                out_l = random.uniform(-0.6, 0.6)
                out_r = random.uniform(-0.6, 0.6)

            # Soft clip & write 16-bit PCM
            s_l = int(max(-1.0, min(1.0, out_l)) * gain)
            s_r = int(max(-1.0, min(1.0, out_r)) * gain)
            buffer.extend(struct.pack("<hh", s_l, s_r))

        return bytes(buffer)

def find_sound_file(preset):
    if not SOUNDS_DIR.exists():
        return None
    for ext in (".ogg", ".mp3", ".wav", ".flac"):
        p = SOUNDS_DIR / f"{preset}{ext}"
        if p.exists():
            return str(p)
    return None

def list_available_presets():
    builtin = [
        {"id": "rain", "name": "Rain Shower", "icon": "󰖗", "type": "synth"},
        {"id": "waves", "name": "Ocean Waves", "icon": "󰤽", "type": "synth"},
        {"id": "campfire", "name": "Campfire", "icon": "󰈸", "type": "synth"},
        {"id": "brown", "name": "Brown Noise", "icon": "󰝚", "type": "synth"},
        {"id": "pink", "name": "Pink Noise", "icon": "󰝚", "type": "synth"},
        {"id": "white", "name": "White Noise", "icon": "󰝚", "type": "synth"},
        {"id": "binaural", "name": "Binaural Alpha (10Hz)", "icon": "󰋋", "type": "synth"},
        {"id": "cafe", "name": "Café Ambience", "icon": "󰅖", "type": "synth"}
    ]
    # Check custom audio files in sounds/
    if SOUNDS_DIR.exists():
        for f in SOUNDS_DIR.iterdir():
            if f.suffix.lower() in (".ogg", ".mp3", ".wav", ".flac"):
                clean_id = f.stem
                if not any(b["id"] == clean_id for b in builtin):
                    builtin.append({
                        "id": clean_id,
                        "name": clean_id.replace("-", " ").replace("_", " ").title(),
                        "icon": "󰝚",
                        "type": "file"
                    })
    return builtin

def run_daemon(preset, volume, timer_minutes=0):
    ensure_state_dir()
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    state = load_state()
    state["playing"] = True
    state["preset"] = preset
    state["volume"] = volume
    state["timer"] = timer_minutes
    state["timer_start"] = int(time.time()) if timer_minutes > 0 else 0
    save_state(state)

    def handle_sigterm(signum, frame):
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGINT, handle_sigterm)

    # Check if a custom audio file exists
    sound_file = find_sound_file(preset)
    
    if sound_file:
        # Use mpv or pw-play for custom audio files
        cmd = ["mpv", "--no-video", "--loop=inf", f"--volume={volume}", sound_file]
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        start_t = time.time()
        while proc.poll() is None:
            time.sleep(1)
            # Sleep timer check
            cur_state = load_state()
            if not cur_state.get("playing", True):
                proc.terminate()
                break
            if timer_minutes > 0 and (time.time() - start_t) >= timer_minutes * 60:
                cur_state["playing"] = False
                cur_state["timer"] = 0
                save_state(cur_state)
                proc.terminate()
                break
        return

    # Procedural real-time synthesis piped to aplay / pw-play
    synth = AudioSynthesizer(preset, volume)
    
    # Try aplay first (ALSA default), fallback to pw-play
    player_cmd = ["aplay", "-r", str(SAMPLE_RATE), "-f", "S16_LE", "-c", "2", "-q"]
    try:
        player_proc = subprocess.Popen(player_cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        player_cmd = ["pw-play", "--format", "s16", "--rate", str(SAMPLE_RATE), "--channels", "2", "-"]
        player_proc = subprocess.Popen(player_cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)

    start_t = time.time()
    last_state_check = time.time()

    try:
        while True:
            chunk = synth.generate_chunk(2048)
            player_proc.stdin.write(chunk)

            now = time.time()
            if now - last_state_check >= 0.5:
                last_state_check = now
                cur_state = load_state()
                if not cur_state.get("playing", True):
                    break
                if cur_state.get("preset") != synth.preset:
                    synth.set_preset(cur_state.get("preset"))
                if int(cur_state.get("volume", 60)) != int(synth.volume * 100):
                    synth.set_volume(cur_state.get("volume", 60))
                if timer_minutes > 0 and (now - start_t) >= timer_minutes * 60:
                    cur_state["playing"] = False
                    cur_state["timer"] = 0
                    save_state(cur_state)
                    break
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        try:
            player_proc.stdin.close()
            player_proc.terminate()
        except Exception:
            pass
        PID_FILE.unlink(missing_ok=True)

def main():
    if len(sys.argv) < 2:
        print("Usage: ambience-engine.py [start|stop|toggle|volume|preset|timer|status|list-presets]")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "start":
        stop_daemon()
        preset = sys.argv[2] if len(sys.argv) > 2 else "rain"
        vol = int(sys.argv[3]) if len(sys.argv) > 3 else 60
        timer_min = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        
        # Fork daemon
        daemon_cmd = [sys.executable, __file__, "_daemon", preset, str(vol), str(timer_min)]
        subprocess.Popen(daemon_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.1)
        print("ok")

    elif cmd == "_daemon":
        preset = sys.argv[2] if len(sys.argv) > 2 else "rain"
        vol = int(sys.argv[3]) if len(sys.argv) > 3 else 60
        timer_min = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        run_daemon(preset, vol, timer_min)

    elif cmd == "stop":
        stop_daemon()
        print("ok")

    elif cmd == "toggle":
        pid = is_running()
        state = load_state()
        if pid:
            stop_daemon()
            print("paused")
        else:
            preset = sys.argv[2] if len(sys.argv) > 2 else state.get("preset", "rain")
            vol = int(sys.argv[3]) if len(sys.argv) > 3 else state.get("volume", 60)
            daemon_cmd = [sys.executable, __file__, "_daemon", preset, str(vol), "0"]
            subprocess.Popen(daemon_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            time.sleep(0.1)
            print("playing")

    elif cmd == "volume":
        vol = max(0, min(100, int(sys.argv[2])))
        state = load_state()
        state["volume"] = vol
        save_state(state)
        print(f"volume: {vol}")

    elif cmd == "preset":
        preset = sys.argv[2]
        state = load_state()
        state["preset"] = preset
        save_state(state)
        if is_running():
            # restart with new preset
            stop_daemon()
            daemon_cmd = [sys.executable, __file__, "_daemon", preset, str(state.get("volume", 60)), str(state.get("timer", 0))]
            subprocess.Popen(daemon_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        print(f"preset: {preset}")

    elif cmd == "timer":
        timer_min = int(sys.argv[2])
        state = load_state()
        state["timer"] = timer_min
        state["timer_start"] = int(time.time()) if timer_min > 0 else 0
        save_state(state)
        print(f"timer: {timer_min}")

    elif cmd == "status":
        state = load_state()
        pid = is_running()
        state["playing"] = bool(pid)
        if state.get("timer", 0) > 0 and state.get("timer_start", 0) > 0:
            elapsed = int(time.time()) - state["timer_start"]
            rem = max(0, (state["timer"] * 60) - elapsed)
            state["timer_remaining"] = rem
        else:
            state["timer_remaining"] = 0
        print(json.dumps(state))

    elif cmd == "list-presets":
        presets = list_available_presets()
        print(json.dumps(presets))

if __name__ == "__main__":
    main()
