import argparse
from ctypes import cast, POINTER
from comtypes import CLSCTX_ALL
from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
import tkinter as tk
import time
import os
import sys

vlc_path = os.path.join(os.path.dirname(__file__), "vlc")

if os.path.exists(vlc_path):
    os.add_dll_directory(vlc_path)
    os.environ["PYTHON_VLC_LIB_PATH"] = os.path.join(vlc_path, "libvlc.dll")
else:
    system_vlc = r"C:\Program Files\VideoLAN\VLC"
    if os.path.exists(system_vlc):
        os.add_dll_directory(system_vlc)
        os.environ["PYTHON_VLC_LIB_PATH"] = os.path.join(system_vlc, "libvlc.dll")

import vlc

def set_windows_volume(percent):
    devices = AudioUtilities.GetSpeakers()
    interface = devices._dev.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
    volume = cast(interface, POINTER(IAudioEndpointVolume))
    volume.SetMasterVolumeLevelScalar(percent / 100, None)
    volume.SetMute(0, None)

def enforce_volume():
    set_windows_volume(args.volume)
    root.after(50, enforce_volume)

def check_ended():
    state = player.get_state()
    if state == vlc.State.Ended or state == vlc.State.Error:
        root.destroy()
    else:
        root.after(500, check_ended)

parser = argparse.ArgumentParser()
parser.add_argument("--file", required=True)
parser.add_argument("--duration", type=int, required=True)
parser.add_argument("--volume", type=int, default=100)
parser.add_argument("--mode", choices=["video", "sound"], required=True)
args = parser.parse_args()

instance = vlc.Instance()
player = instance.media_player_new()
media = instance.media_new(args.file)
player.set_media(media)
player.audio_set_volume(150)
set_windows_volume(args.volume)

if args.mode == "video":
    root = tk.Tk()
    root.attributes("-fullscreen", True)
    root.configure(bg="black")
    root.protocol("WM_DELETE_WINDOW", lambda: None)
    root.bind("<Escape>", lambda e: None)
    root.bind("<Alt-F4>", lambda e: None)
    root.attributes("-topmost", True)
    root.lift()
    root.focus_force()
    player.set_hwnd(root.winfo_id())
    player.play()
    root.after(args.duration * 1000, root.destroy)
    root.after(50, enforce_volume)
    root.after(500, check_ended)
    root.mainloop()

elif args.mode == "sound":
    player.play()
    end_time = time.time() + args.duration
    while time.time() < end_time:
        state = player.get_state()
        if state == vlc.State.Ended or state == vlc.State.Error:
            break
        set_windows_volume(args.volume)
        time.sleep(0.05)
