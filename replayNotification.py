from win10toast import ToastNotifier
import obspython as obs

class MyToastNotifier(ToastNotifier):
    def __init__(self):
        super().__init__()

    def on_destroy(self, hwnd, msg, wparam, lparam):
        super().on_destroy(hwnd, msg, wparam, lparam)
        return 0

def send_notification(title, message):
    toaster = MyToastNotifier()
    toaster.show_toast(title, message, duration=5, threaded=True)

def on_event(event):
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED:
        send_notification("OBS Notification", "Replay buffer saved.")
    elif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED:
        send_notification("OBS Notification", "Replay buffer started.")

def script_load(settings):
    # Register the event callback
    obs.obs_frontend_add_event_callback(on_event)

def script_unload():
    # Unregister the event callback
    obs.obs_frontend_remove_event_callback(on_event)