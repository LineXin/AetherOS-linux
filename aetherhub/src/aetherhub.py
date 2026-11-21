#!/usr/bin/env python3
import platform, subprocess
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

VERSION = "0.2.0"
HELPER = "/usr/local/sbin/aetheros-tune"

def output(args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "Unavailable"

def tune(*args):
    try:
        result = subprocess.run(["sudo", HELPER, *args], text=True, capture_output=True)
        if result.returncode:
            return (result.stderr or result.stdout or "Operation failed").strip()
        return (result.stdout or "Setting applied").strip()
    except Exception as exc:
        return str(exc)

class AetherHub(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aetheros.AetherHub")
        self.connect("activate", self.activate)

    def activate(self, app):
        win = Gtk.ApplicationWindow(application=app, title="AetherHub")
        win.set_default_size(820, 700)
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        root.set_margin_top(22); root.set_margin_bottom(22)
        root.set_margin_start(24); root.set_margin_end(24)
        root.add_css_class("hub")

        head = Gtk.Box(spacing=12)
        mark = Gtk.Label(label="Ⓐ"); mark.add_css_class("mark")
        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        name = Gtk.Label(label="AetherHub"); name.set_xalign(0); name.add_css_class("title-1")
        tagline = Gtk.Label(label="PURE. FAST. REFINED."); tagline.set_xalign(0); tagline.add_css_class("muted")
        titles.append(name); titles.append(tagline); head.append(mark); head.append(titles)
        root.append(head)

        syscard = self.card()
        syscard.append(self.label("SYSTEM OVERVIEW", "section"))
        for key, value in [
            ("OS", output(["sh","-c","grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d '\"'"])),
            ("Kernel", platform.release()), ("Architecture", platform.machine()),
            ("CPU", output(["sh","-c","grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-"])),
        ]:
            row = Gtk.Box(spacing=8)
            k = self.label(key, "muted"); k.set_size_request(120, -1)
            v = self.label(value or "Unknown", "value"); v.set_wrap(True)
            row.append(k); row.append(v); syscard.append(row)
        root.append(syscard)

        perf = self.card()
        perf.append(self.label("PERFORMANCE", "section"))
        govrow = Gtk.Box(spacing=8)
        govrow.append(self.label("CPU governor", "value"))
        gov = Gtk.DropDown.new_from_strings(["powersave","schedutil","performance","ondemand","conservative"])
        govrow.append(gov)
        applygov = Gtk.Button(label="Apply governor")
        applygov.connect("clicked", lambda *_: self.notify(tune("governor", gov.get_selected_item().get_string())))
        govrow.append(applygov); perf.append(govrow)

        swaprow = Gtk.Box(spacing=8)
        swaprow.append(self.label("Swappiness (0–100)", "value"))
        swap = Gtk.SpinButton.new_with_range(0,100,1); swap.set_value(60)
        swaprow.append(swap)
        applyswap = Gtk.Button(label="Apply")
        applyswap.connect("clicked", lambda *_: self.notify(tune("swappiness", str(swap.get_value_as_int()))))
        swaprow.append(applyswap); perf.append(swaprow)

        zrow = Gtk.Box(spacing=8)
        zrow.append(self.label("ZRAM", "value"))
        for caption, action in [("Enable","enable"),("Disable","disable"),("Status","status")]:
            b=Gtk.Button(label=caption)
            b.connect("clicked", lambda _, a=action: self.notify(tune("zram",a)))
            zrow.append(b)
        perf.append(zrow); root.append(perf)

        services = self.card()
        services.append(self.label("SYSTEM SERVICES", "section"))
        services.append(self.label("Only manage services you actually use. Stopping a service may disable related hardware or features.", "muted"))
        for unit in ["bluetooth","cups","thermald"]:
            row=Gtk.Box(spacing=8)
            row.append(self.label(unit, "value"))
            for action in ["start","stop","enable","disable","status"]:
                b=Gtk.Button(label=action.capitalize())
                b.connect("clicked", lambda _, u=unit, a=action: self.notify(tune("service",u,a)))
                row.append(b)
            services.append(row)
        root.append(services)

        appearance = self.card()
        appearance.append(self.label("APPEARANCE", "section"))
        wallpaper = Gtk.Button(label="Apply AetherOS wallpaper (XFCE)")
        wallpaper.connect("clicked", lambda *_: self.notify(output(["/usr/local/bin/aetheros-wallpaper"])))
        appearance.append(wallpaper)
        root.append(appearance)

        note=self.label("Changes to CPU governor may reset after reboot. Swappiness is applied immediately; the system default is stored in /etc/sysctl.d/90-aetheros.conf. ZRAM requires zram-tools.", "muted")
        note.set_wrap(True); root.append(note)

        css=Gtk.CssProvider()
        css.load_from_data(b"""
          .hub { background:#10131c; color:#edf0f7; }
          .mark { color:#ff805b; font-size:42px; }
          .muted { color:#a4adbf; }
          .section { color:#ff9877; font-weight:700; letter-spacing:1px; }
          .value { color:#f2f4fa; }
          .panel { background:#202635; border-radius:14px; padding:16px; }
          button { padding:7px 11px; }
        """)
        Gtk.StyleContext.add_provider_for_display(win.get_display(),css,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        win.set_child(root); win.present()

    def card(self):
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=10)
        box.add_css_class("panel")
        return box

    def label(self, text, style=None):
        label=Gtk.Label(label=text); label.set_xalign(0)
        if style: label.add_css_class(style)
        return label

    def notify(self, message):
        dialog=Gtk.AlertDialog(message=message or "Done")
        dialog.show(self.get_active_window())

if __name__ == "__main__":
    AetherHub().run()
