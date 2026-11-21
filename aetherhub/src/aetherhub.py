#!/usr/bin/env python3
import os
import platform
import subprocess
import shutil
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib

APP_NAME = "AetherHub"
VERSION = "0.1.0"

def command_output(command):
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "Unavailable"

def memory_info():
    try:
        values = {}
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                key, value = line.split(":", 1)
                values[key] = int(value.strip().split()[0])
        total = values.get("MemTotal", 0) / 1024
        available = values.get("MemAvailable", 0) / 1024
        used = total - available
        return f"{used:.0f} MiB used / {total:.0f} MiB total"
    except Exception:
        return "Unavailable"

class AetherHub(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aetheros.AetherHub")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        window = Gtk.ApplicationWindow(application=app)
        window.set_title("AetherHub")
        window.set_default_size(760, 520)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.add_css_class("hub-window")
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header.set_margin_top(24)
        header.set_margin_bottom(16)
        header.set_margin_start(24)
        header.set_margin_end(24)

        logo = Gtk.Label(label="✦")
        logo.add_css_class("logo")
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title = Gtk.Label(label="AetherHub")
        title.set_xalign(0)
        title.add_css_class("title-1")
        subtitle = Gtk.Label(label="Your AetherOS control center")
        subtitle.set_xalign(0)
        subtitle.add_css_class("dim-label")
        title_box.append(title)
        title_box.append(subtitle)
        header.append(logo)
        header.append(title_box)
        root.append(header)

        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        root.append(separator)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        content.set_margin_top(24)
        content.set_margin_bottom(24)
        content.set_margin_start(24)
        content.set_margin_end(24)

        welcome = Gtk.Label(label="Welcome to AetherOS")
        welcome.set_xalign(0)
        welcome.add_css_class("title-2")
        content.append(welcome)

        info_grid = Gtk.Grid(column_spacing=12, row_spacing=12)
        info_grid.set_column_homogeneous(True)
        details = [
            ("Operating system", command_output(["bash", "-lc", "cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2- | tr -d '\"'"])),
            ("AetherHub version", VERSION),
            ("Kernel", platform.release()),
            ("Architecture", platform.machine()),
            ("Processor", command_output(["bash", "-lc", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs"])),
            ("Memory", memory_info()),
        ]
        for index, (name, value) in enumerate(details):
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            card.add_css_class("info-card")
            label = Gtk.Label(label=name)
            label.set_xalign(0)
            label.add_css_class("dim-label")
            val = Gtk.Label(label=value or "Unknown")
            val.set_xalign(0)
            val.set_wrap(True)
            val.add_css_class("heading")
            card.append(label)
            card.append(val)
            info_grid.attach(card, index % 2, index // 2, 1, 1)
        content.append(info_grid)

        section = Gtk.Label(label="Quick actions")
        section.set_xalign(0)
        section.add_css_class("title-3")
        content.append(section)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        for label, command in [
            ("System Settings", ["xfce4-settings-manager"]),
            ("Terminal", ["xfce4-terminal"]),
            ("File Manager", ["thunar"]),
        ]:
            button = Gtk.Button(label=label)
            button.add_css_class("suggested-action")
            button.connect("clicked", self.launch, command)
            actions.append(button)
        content.append(actions)

        about = Gtk.Label(label="AetherOS is an independent Linux distribution project.\nBuilt with Debian, open-source software, and a little bit of ambition.")
        about.set_xalign(0)
        about.set_wrap(True)
        about.add_css_class("dim-label")
        content.append(about)

        root.append(content)
        window.set_child(root)

        css = Gtk.CssProvider()
        css.load_from_data(b"""
            .hub-window { background: #11131a; color: #e8eaf2; }
            .logo { font-size: 40px; color: #ff754c; }
            .info-card { background: #20232d; border-radius: 12px; padding: 16px; }
            button { padding: 10px 16px; }
        """)
        Gtk.StyleContext.add_provider_for_display(
            window.get_display(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        window.present()

    def launch(self, button, command):
        try:
            subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as error:
            print(f"Could not launch {command[0]}: {error}")

if __name__ == "__main__":
    AetherHub().run()
