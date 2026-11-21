#!/usr/bin/env python3
"""AetherHub — AetherOS system settings."""
import platform
import subprocess
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gio

HELPER = "/usr/local/sbin/aetheros-tune"
ACCENT = "#ef7049"

def run(args, privileged=False):
    command = (["sudo", HELPER] if privileged else args[:1]) + (args if privileged else args[1:])
    try:
        p = subprocess.run(command, text=True, capture_output=True, timeout=12)
        return p.returncode == 0, (p.stdout or p.stderr).strip()
    except Exception as exc:
        return False, str(exc)

def read_value(path, fallback="Not available"):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return fallback

class AetherHub(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aetheros.AetherHub", flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("AetherHub")
        win.set_default_size(920, 650)

        shell = Gtk.Box(spacing=0)
        shell.add_css_class("window-bg")
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        sidebar.set_size_request(218, -1)
        sidebar.set_margin_top(22); sidebar.set_margin_bottom(18)
        sidebar.set_margin_start(18); sidebar.set_margin_end(14)
        brand = Gtk.Box(spacing=10)
        symbol = Gtk.Label(label="Ⓐ"); symbol.add_css_class("brand-symbol")
        brand_text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        brand_name = Gtk.Label(label="AetherHub"); brand_name.set_xalign(0); brand_name.add_css_class("brand-name")
        brand_sub = Gtk.Label(label="SYSTEM SETTINGS"); brand_sub.set_xalign(0); brand_sub.add_css_class("eyebrow")
        brand_text.append(brand_name); brand_text.append(brand_sub); brand.append(symbol); brand.append(brand_text)
        sidebar.append(brand)
        sidebar.append(Gtk.Separator())

        stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE, transition_duration=150)
        stack.set_hexpand(True); stack.set_vexpand(True)
        nav = Gtk.StackSidebar(stack=stack); nav.set_size_request(180, -1)
        sidebar.append(nav); sidebar.set_margin_bottom(20)
        shell.append(sidebar)
        shell.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))

        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        top = Gtk.Box(spacing=8)
        top.set_margin_top(22); top.set_margin_bottom(16); top.set_margin_start(28); top.set_margin_end(28)
        page_title = Gtk.Label(label="Overview"); page_title.set_xalign(0); page_title.add_css_class("page-title")
        top.append(page_title); main.append(top); main.append(Gtk.Separator())
        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        body.set_margin_top(24); body.set_margin_bottom(24); body.set_margin_start(28); body.set_margin_end(28)
        scroller = Gtk.ScrolledWindow(); scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC); scroller.set_child(body)
        main.append(scroller); shell.append(main)

        def add_page(name, icon, title):
            page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
            heading = Gtk.Label(label=title); heading.set_xalign(0); heading.add_css_class("section-title")
            page.append(heading)
            stack.add_titled(page, name.lower(), icon + "  " + name)
            return page

        overview = add_page("Overview", "⌂", "Your system at a glance")
        grid = Gtk.Grid(column_spacing=12, row_spacing=12)
        grid.set_column_homogeneous(True)
        details = [
            ("Operating system", read_value("/etc/os-release").split('PRETTY_NAME=')[-1].splitlines()[0].strip('"') if "PRETTY_NAME=" in read_value("/etc/os-release") else "AetherOS"),
            ("Kernel", platform.release()), ("Architecture", platform.machine()),
            ("CPU", read_value("/proc/cpuinfo", "").split("model name\t: ")[-1].splitlines()[0] if "model name" in read_value("/proc/cpuinfo","") else "Unknown"),
            ("Memory", read_value("/proc/meminfo","").splitlines()[0] if read_value("/proc/meminfo","") else "Unknown"),
            ("AetherHub", "Version 0.3"),
        ]
        for i,(key,val) in enumerate(details):
            card=self.card()
            k=self.label(key,"field-label"); v=self.label(val,"field-value"); v.set_wrap(True)
            card.append(k); card.append(v); grid.attach(card,i%2,i//2,1,1)
        overview.append(grid)
        overview.append(self.info("AetherOS", "PURE. FAST. REFINED.  ·  Debian-based desktop system"))

        performance = add_page("Performance", "◈", "Performance")
        performance.append(self.info("CPU frequency scaling", "Choose a governor supported by your CPU driver. The setting applies immediately and may reset after reboot."))
        govrow=Gtk.Box(spacing=10)
        govrow.append(self.label("CPU governor","field-label"))
        governor=Gtk.DropDown.new_from_strings(["powersave","schedutil","performance","ondemand","conservative"])
        govrow.append(governor)
        apply=Gtk.Button(label="Apply"); apply.add_css_class("suggested-action")
        apply.connect("clicked",lambda *_: self.action("governor",governor.get_selected_item().get_string()))
        govrow.append(apply); performance.append(self.card_with(govrow))
        swaprow=Gtk.Box(spacing=12)
        swaprow.append(self.label("VM swappiness","field-label"))
        sw=Gtk.SpinButton.new_with_range(0,100,1); sw.set_value(60); swaprow.append(sw)
        swapply=Gtk.Button(label="Apply"); swapply.connect("clicked",lambda *_: self.action("swappiness",str(sw.get_value_as_int())))
        swaprow.append(swapply); performance.append(self.card_with(swaprow))
        zramrow=Gtk.Box(spacing=10)
        zramrow.append(self.label("ZRAM swap","field-label"))
        for text,cmd in [("Enable",["zram","enable"]),("Disable",["zram","disable"]),("Check status",["zram","status"])]:
            b=Gtk.Button(label=text); b.connect("clicked",lambda _,c=cmd:self.action(*c)); zramrow.append(b)
        performance.append(self.card_with(zramrow))

        services = add_page("Services", "⚙", "Background services")
        services.append(self.info("Service controls", "Turn services on only when you need them. Disabling a service may remove related functionality."))
        for unit,description in [
            ("bluetooth","Bluetooth device support"),
            ("cups","Printing service"),
            ("thermald","Intel thermal management (where supported)")
        ]:
            row=Gtk.Box(spacing=12)
            texts=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=2); texts.set_hexpand(True)
            nm=self.label(unit,"field-value"); ds=self.label(description,"secondary")
            texts.append(nm); texts.append(ds); row.append(texts)
            for label,action in [("Start","start"),("Stop","stop"),("Enable","enable"),("Disable","disable")]:
                b=Gtk.Button(label=label); b.connect("clicked",lambda _,u=unit,a=action:self.action("service",u,a)); row.append(b)
            services.append(self.card_with(row))

        appearance = add_page("Appearance", "◐", "Appearance")
        appearance.append(self.info("AetherOS wallpapers", "Choose the default AetherOS wallpaper for your desktop session."))
        for label,path in [
            ("Mountain dusk","/usr/share/aetheros/branding/aetheros-wallpaper-mountain.svg"),
            ("Graphite abstract","/usr/share/aetheros/branding/aetheros-wallpaper-abstract.svg")
        ]:
            b=Gtk.Button(label=label); b.set_halign(Gtk.Align.START)
            b.connect("clicked",lambda _,p=path:self.wallpaper(p)); appearance.append(self.card_with(b))

        about=add_page("About", "ⓘ", "About AetherHub")
        about.append(self.info("AetherHub 0.3", "A native GTK4 control panel for AetherOS. System changes are performed by a restricted helper; administrative authentication is requested through sudo when required."))
        about.append(self.info("Project", "AetherOS is an independent Debian-based Linux distribution project."))
        stack.connect("notify::visible-child-name",lambda s,_:page_title.set_text({
            "overview":"Overview","performance":"Performance","services":"Services","appearance":"Appearance","about":"About"
        }.get(s.get_visible_child_name(),"Settings")))
        main_body = body
        # Stack owns the pages; use it as the main content instead of the initial placeholder body.
        scroller.set_child(stack)
        win.set_child(shell)
        self.install_css(win)
        win.present()

    def action(self,*args):
        ok,msg=run(list(args),privileged=True)
        self.dialog(msg or ("Setting applied" if ok else "Operation failed"))

    def wallpaper(self,path):
        if not path.startswith("/usr/share/aetheros/branding/"):
            return
        try:
            p=subprocess.run(["/usr/local/bin/aetheros-wallpaper",path],capture_output=True,text=True)
            self.dialog(p.stderr.strip() or "Wallpaper request sent to the desktop session.")
        except Exception as exc:
            self.dialog(str(exc))

    def dialog(self,message):
        d=Gtk.AlertDialog(message=message or "Done")
        d.show(self.get_active_window())

    def label(self,text,style=None):
        l=Gtk.Label(label=text); l.set_xalign(0)
        if style:l.add_css_class(style)
        return l

    def card(self):
        b=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=7); b.add_css_class("card"); return b

    def card_with(self,child):
        b=self.card(); b.append(child); return b

    def info(self,title,description):
        b=self.card(); b.append(self.label(title,"field-value"))
        d=self.label(description,"secondary"); d.set_wrap(True); b.append(d); return b

    def install_css(self,win):
        css=Gtk.CssProvider()
        css.load_from_data(b"""
        .window-bg { background:#11151d; color:#e8ebf2; }
        .brand-symbol { color:#f17850; font-size:36px; }
        .brand-name { font-size:19px; font-weight:700; color:#f3f4f7; }
        .eyebrow { color:#929bab; font-size:9px; letter-spacing:1.6px; }
        .page-title { font-size:22px; font-weight:650; color:#f3f4f7; }
        .section-title { font-size:18px; font-weight:600; color:#f3f4f7; }
        .card { background:#1c2330; border:1px solid #2b3444; border-radius:10px; padding:16px; }
        .field-label { color:#aab3c2; font-size:12px; }
        .field-value { color:#f1f3f7; font-size:14px; font-weight:600; }
        .secondary { color:#98a2b3; font-size:12px; }
        button { border-radius:7px; padding:7px 12px; }
        button.suggested-action { background:#e96f4b; color:white; }
        stacksidebar row:selected { background:#2b3545; border-radius:7px; }
        """)
        Gtk.StyleContext.add_provider_for_display(win.get_display(),css,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

if __name__=="__main__":
    AetherHub().run()
